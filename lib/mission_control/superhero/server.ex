defmodule MissionControl.SuperheroServer do
  use GenServer
  require Logger

  alias MissionControl.SuperheroRegistry
  alias Horde.Registry

  @polling_interval 4000
  @max_health 100
  @default_fights 0

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: via_tuple(id))
  end

  @impl true
  def init(id) do
    Process.flag(:trap_exit, true)

    Logger.info("Initializing superhero server for #{id}")
    send(self(), :init_superhero)

    initial_hero = struct!(MissionControl.Superhero, %{id: id})
    {:ok, %{superhero: initial_hero, current_superhero: nil}}
  end

  @impl true
  def handle_info(:init_superhero, %{superhero: superhero} = state) do
    case MissionControl.get_superhero(superhero.id) do
      {:ok, [existing_superhero]} ->
        Logger.info("Using existing superhero #{superhero.id}.")

        # current_superhero = what's in Raft (for optimistic locking)
        # superhero = updated with current node
        updated_attrs =
          Map.from_struct(existing_superhero)
          |> Map.take(Ash.Resource.Info.attribute_names(MissionControl.Superhero))
          |> Map.put(:node, node())

        updated_superhero = struct!(MissionControl.Superhero, updated_attrs)

        new_state = %{
          state
          | superhero: updated_superhero,
            current_superhero: existing_superhero
        }

        send(self(), :update_superhero)
        schedule_next_action()

        {:noreply, new_state}

      {:ok, []} ->
        Logger.error(
          "Superhero #{superhero.id} not found in Raft store. It should have been created before starting the server."
        )

        {:stop, :superhero_not_found, state}

      {:error, :timeout} ->
        Logger.info("Timeout occurred, retrying superhero initialization.")
        Process.send_after(self(), :init_superhero, 2000)
        {:noreply, state}

      {:error, error} ->
        Logger.error("Failed to get superhero #{superhero.id}: #{inspect(error)}")
        {:stop, :failed_to_get_superhero, state}
    end
  end

  @impl true
  def handle_info(:decide_action, %{superhero: superhero} = state) do
    updated_superhero =
      case random_action() do
        :fighting ->
          GenServer.cast(self(), :fighting_crime)
          Map.put(superhero, :is_patrolling, true)

        :resting ->
          GenServer.cast(self(), :resting)
          Map.put(superhero, :is_patrolling, false)
      end

    schedule_next_action()
    {:noreply, %{state | superhero: updated_superhero}}
  end

  @impl true
  def handle_info(
        :update_superhero,
        %{current_superhero: current_superhero, superhero: updated_superhero} = state
      ) do
    updated_attrs =
      Map.from_struct(updated_superhero)
      |> Map.take(Ash.Resource.Info.action(MissionControl.Superhero, :update).accept)

    new_state =
      case MissionControl.update_superhero(current_superhero, updated_attrs) do
        {:ok, updated_ash} ->
          Logger.info("Superhero #{updated_superhero.id} successfully updated in store.")
          %{state | current_superhero: updated_ash, superhero: updated_ash}

        {:error, error} ->
          handle_update_error(error, updated_superhero, current_superhero, state)
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:resting, %{superhero: superhero} = state) do
    health_gain = :rand.uniform(40)
    new_health = min(superhero.health + health_gain, @max_health)
    updated_superhero = Map.put(superhero, :health, new_health)

    Logger.info(
      "#{superhero.name} is resting and has regained #{health_gain} health points, new health: #{new_health}."
    )

    send(self(), :update_superhero)
    {:noreply, %{state | superhero: updated_superhero}}
  end

  @impl true
  def handle_cast(:fighting_crime, %{superhero: superhero} = state) do
    case :rand.uniform(2) do
      1 -> {:noreply, handle_win(superhero, state)}
      2 -> {:noreply, handle_loss(superhero, state)}
    end
  end

  @impl true
  def terminate(reason, %{superhero: superhero}) do
    Logger.info(
      "Terminating superhero server for #{superhero.name} with reason: #{inspect(reason)}"
    )

    :ok
  end

  defp handle_win(superhero, state) do
    updated_superhero = Map.update(superhero, :fights_won, @default_fights, &(&1 + 1))
    Logger.info("#{superhero.name} won a fight, total wins: #{updated_superhero.fights_won}")
    send(self(), :update_superhero)
    %{state | superhero: updated_superhero}
  end

  defp handle_loss(superhero, state) do
    health_loss = :rand.uniform(40)
    updated_superhero = update_superhero_losses(superhero, health_loss)

    Logger.info(
      "#{updated_superhero.name} lost a fight, lost #{health_loss} health, remaining health: #{updated_superhero.health}"
    )

    if updated_superhero.health <= 0 do
      handle_critical_health(updated_superhero, state)
    else
      send(self(), :update_superhero)
      %{state | superhero: updated_superhero}
    end
  end

  defp handle_critical_health(updated_superhero, state) do
    Logger.warning("#{updated_superhero.name} has health <= 0, terminating.")

    case MissionControl.delete_superhero(updated_superhero) do
      :ok ->
        Logger.info("Superhero #{updated_superhero.id} deleted successfully via Ash")

      {:ok, _deleted} ->
        Logger.info("Superhero #{updated_superhero.id} deleted successfully via Ash")

      {:error, error} ->
        Logger.error("Failed to delete superhero #{updated_superhero.id}: #{inspect(error)}")
    end

    %{state | superhero: updated_superhero}
  end

  defp handle_update_error(error, updated_superhero, current_superhero, state) do
    is_conflict =
      case error do
        %Ash.Error.Invalid{errors: errors} ->
          Enum.any?(errors, fn err ->
            err_string = inspect(err)

            String.contains?(err_string, "Conflict") or
              String.contains?(err_string, "updated by another node")
          end)

        _ ->
          false
      end

    if is_conflict do
      Logger.info(
        "Superhero #{updated_superhero.id} was updated by another node, fetching current value."
      )

      case MissionControl.get_superhero(updated_superhero.id) do
        {:ok, [current_ash]} ->
          %{state | current_superhero: current_ash, superhero: current_ash}

        _ ->
          Logger.warning("Failed to fetch current superhero value, keeping local state")
          %{state | superhero: current_superhero}
      end
    else
      Logger.warning("Update failed for superhero #{updated_superhero.id}: #{inspect(error)}")
      %{state | superhero: current_superhero}
    end
  end

  defp update_superhero_losses(superhero, health_loss) do
    superhero
    |> Map.update(:health, @max_health, &(&1 - health_loss))
    |> Map.update(:fights_lost, @default_fights, &(&1 + 1))
  end

  defp random_action do
    if :rand.uniform(4) == 1, do: :resting, else: :fighting
  end

  defp schedule_next_action do
    Process.send_after(self(), :decide_action, @polling_interval)
  end

  def via_tuple(id), do: {:via, Registry, {SuperheroRegistry, id}}
end
