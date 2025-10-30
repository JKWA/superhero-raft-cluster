defmodule MissionControl.SuperheroApi do
  require Logger

  alias MissionControl.{
    SuperheroRegistry,
    SuperheroServer,
    SuperheroSupervisor,
    SuperheroRegistryHandler
  }

  alias Horde.{DynamicSupervisor, Registry}
  require Logger

  def start(id) do
    child_spec = %{
      id: id,
      start: {SuperheroServer, :start_link, [id]}
    }

    case DynamicSupervisor.start_child(SuperheroSupervisor, child_spec) do
      {:ok, pid} ->
        Logger.info("Superhero created successfully: #{id} with PID #{inspect(pid)}")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to create superhero: #{id} due to #{inspect(reason)}")
        {:error, reason}
    end
  end

  def stop(id) do
    case SuperheroRegistryHandler.get_pid_for_superhero(id) do
      nil ->
        {:error, :not_found}

      pid ->
        :ok = DynamicSupervisor.terminate_child(SuperheroSupervisor, pid)
        :ok = Registry.unregister(SuperheroRegistry, id)

        {:ok, :terminated}
    end
  end

  def get_details(id) do
    GenServer.call(SuperheroServer.via_tuple(id), :get_details)
  end

  def get_all_superheroes_with_details do
    SuperheroRegistryHandler.get_all_superheroes()
    |> Enum.map(fn id ->
      get_details(id)
      |> Map.put(:node, SuperheroRegistryHandler.get_node_for_superhero(id))
    end)
  end
end
