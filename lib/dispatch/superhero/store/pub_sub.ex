defmodule Dispatch.Store.PubSub do
  use GenServer
  require Logger

  alias Dispatch.Superhero
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
  def handle_cast({:key_updated, key, value}, state) do
    Logger.info("CAST Received key update: #{key} with value: #{inspect(value)}")

    PubSub.broadcast(
      Dispatch.PubSub,
      topic(),
      {:update_superhero, value}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:key_deleted, key}, state) do
    Logger.info("CAST Received key delete: #{key}}")

    PubSub.broadcast(
      Dispatch.PubSub,
      topic(),
      {:delete_superhero, %Superhero{id: key}}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:failure, key, reason, current_state}, state) do
    Logger.error(
      "CAST Received failure on #{key} with reason: #{reason} state: #{inspect(current_state)}"
    )

    {:noreply, state}
  end
end
