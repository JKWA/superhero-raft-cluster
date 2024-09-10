defmodule Dispatch.SuperheroServer do
  use GenServer
  require Logger

  alias Dispatch.{SuperheroRegistry, Superhero, SuperheroApi, Store}
  alias Horde.Registry
  alias Store.SuperheroStore

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

    {:ok, %{superhero: %Superhero{id: id}, current_superhero: nil}}
  end

  @impl true
  def handle_info(:init_superhero, %{superhero: superhero} = state) do
    case SuperheroStore.get_superhero(superhero.id) do
      {:ok, existing_superhero} ->
        Logger.info("Using existing superhero #{superhero.id}.")

        new_state = %{
          state
          | superhero: existing_superhero |> Map.put(:node, node()),
            current_superhero: existing_superhero
        }

        send(self(), :update_superhero)
        schedule_next_action()

        {:noreply, new_state}

      {:error, :not_found} ->
        new_superhero = generate_new_superhero(superhero)

        new_state = %{
          state
          | superhero: new_superhero |> Map.put(:node, node()),
            current_superhero: new_superhero
        }

        send(self(), :update_superhero)
        schedule_next_action()

        {:noreply, new_state}

      {:error, :timeout} ->
        Logger.info("Timeout occurred, retrying superhero initialization.")
        Process.send_after(self(), :init_superhero, 2000)
        {:noreply, state}
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
    new_state =
      case SuperheroStore.upsert_superhero(current_superhero, updated_superhero) do
        {:ok, _} ->
          Logger.info("Superhero #{updated_superhero.id} successfully updated in store.")
          %{state | current_superhero: updated_superhero, superhero: updated_superhero}

        {:error, :not_match, current_value} ->
          Logger.info(
            "Superhero #{updated_superhero.id} was updated in store by another node #{inspect(current_value)}."
          )

          %{state | current_superhero: current_value, superhero: current_value}

        {:error, :timeout} ->
          Logger.info("Update store timeout for superhero #{updated_superhero.id}, reverted.")
          %{state | superhero: current_superhero}
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

  defp generate_new_superhero(superhero) do
    new_superhero =
      superhero
      |> Map.put(:node, node())
      |> Map.put(:name, "#{Faker.Superhero.prefix()} #{Faker.Superhero.name()}")

    send(self(), :update_superhero)
    new_superhero
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
      handle_critical_health(updated_superhero)
    else
      send(self(), :update_superhero)
      %{state | superhero: updated_superhero}
    end
  end

  defp handle_critical_health(updated_superhero) do
    Logger.warning("#{updated_superhero.name} has health <= 0, terminating.")
    SuperheroStore.delete_superhero(updated_superhero.id)
    SuperheroApi.stop(updated_superhero.id)
    {:noreply, updated_superhero}
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
