defmodule DispatchWeb.DispatchLive.Index do
  use DispatchWeb, :live_view
  alias MissionControl.Store
  alias Phoenix.PubSub

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(MissionControl.PubSub, Store.PubSub.topic())
    :net_kernel.monitor_nodes(true, [])

    new_socket =
      socket
      |> assign(:city_name, Application.get_env(:dispatch, :city_name))
      |> assign_dispatch_centers()

    case MissionControl.list_superheroes() do
      {:ok, superheroes} ->
        new_socket =
          new_socket
          |> stream(:superheroes, superheroes)

        {:ok, new_socket}

      {:error, error} ->
        new_socket =
          new_socket
          |> put_flash(:error, "Failed to load superheroes: #{inspect(error)}")
          |> stream(:superheroes, [])

        {:ok, new_socket}
    end
  end

  defp assign_dispatch_centers(socket) do
    case MissionControl.list_dispatch_centers() do
      {:ok, centers} ->
        node_list = Enum.map(centers, & &1.node)
        assign(socket, :node_list, node_list)

      {:error, _error} ->
        assign(socket, :node_list, [])
    end
  end

  @impl true
  def handle_event("create", _params, socket) do
    superhero_id = UUID.uuid4()

    superhero_attrs = %{
      id: superhero_id,
      name: MissionControl.Superhero.Factory.generate_name()
    }

    case MissionControl.create_superhero(superhero_attrs) do
      {:ok, _superhero} ->
        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to create superhero: #{superhero_id} due to #{inspect(error)}")

        new_socket =
          socket |> put_flash(:error, "Failed to create superhero: #{superhero_id}.")

        {:noreply, new_socket}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case MissionControl.get_superhero(id) do
      {:ok, [superhero]} ->
        case MissionControl.delete_superhero(superhero) do
          :ok ->
            {:noreply, socket}

          {:ok, _deleted} ->
            {:noreply, socket}

          {:error, error} ->
            Logger.error("Failed to delete superhero #{id}: #{inspect(error)}")
            {:noreply, socket |> put_flash(:error, "Failed to delete superhero #{id}.")}
        end

      {:ok, []} ->
        Logger.warning("Superhero #{id} not found for deletion")
        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to get superhero #{id}: #{inspect(error)}")
        {:noreply, socket |> put_flash(:error, "Failed to delete superhero #{id}.")}
    end
  end

  def handle_event("stop_node", %{"node" => node_name}, socket) do
    case MissionControl.get_dispatch_center(String.to_atom(node_name)) do
      {:ok, [center]} ->
        case MissionControl.shutdown_dispatch_center(center) do
          :ok ->
            Logger.info("Successfully initiated shutdown of #{node_name}")

          {:ok, _} ->
            Logger.info("Successfully initiated shutdown of #{node_name}")

          {:error, error} ->
            Logger.error("Failed to shutdown #{node_name}: #{inspect(error)}")
        end

      {:ok, []} ->
        Logger.error("Node not found: #{node_name}")

      {:error, error} ->
        Logger.error("Failed to get dispatch center #{node_name}: #{inspect(error)}")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_superhero, superhero}, socket) do
    new_socket =
      socket
      |> stream_insert(:superheroes, superhero)

    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:delete_superhero, superhero}, socket) do
    new_socket =
      socket
      |> stream_delete(:superheroes, superhero)

    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:nodeup, node}, socket) do
    Logger.info("Node joined the cluster: #{inspect(node)}")

    new_socket = assign_dispatch_centers(socket)
    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:nodedown, node}, socket) do
    Logger.info("Node left the cluster: #{inspect(node)}")

    new_socket = assign_dispatch_centers(socket)
    {:noreply, new_socket}
  end
end
