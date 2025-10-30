defmodule MissionControl.Store.PubSub do
  use GenServer
  require Logger

  alias Phoenix.PubSub

  def topic do
    "superhero_data"
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: :message_server)
  end

  @impl true
  def init(arg) do
    {:ok, arg}
  end

  @impl true
  def handle_cast({:key_updated, _key, value}, state) do
    # Value is a plain map from Raft - convert to Ash Resource struct for broadcast
    ash_hero = struct!(MissionControl.Superhero.Resource, value)

    PubSub.broadcast(
      MissionControl.PubSub,
      topic(),
      {:update_superhero, ash_hero}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:key_deleted, key}, state) do
    # Create minimal Ash Resource struct with just the id for deletion events
    ash_hero = struct!(MissionControl.Superhero.Resource, %{id: key})

    PubSub.broadcast(
      MissionControl.PubSub,
      topic(),
      {:delete_superhero, ash_hero}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:failure, key, reason, current_state}, state) do
    Logger.error(
      "Received failure on #{key} with reason: #{reason} state: #{inspect(current_state)}"
    )

    {:noreply, state}
  end
end
