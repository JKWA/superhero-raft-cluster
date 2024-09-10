defmodule DispatchWeb.DispatchLive.Index do
  use DispatchWeb, :live_view
  alias Dispatch.{SuperheroApi, Store}
  alias Phoenix.PubSub
  alias Store.SuperheroStore

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(Dispatch.PubSub, Store.PubSub.topic())
    :net_kernel.monitor_nodes(true, [])

    new_socket =
      socket
      |> assign(:city_name, Application.get_env(:dispatch, :city_name))
      |> assign(:node_list, Node.list())

    case SuperheroStore.get_all_superheroes() do
      {:ok, superheroes} ->
        new_socket =
          new_socket
          |> stream(:superheroes, superheroes)

        {:ok, new_socket}

      {:error, reason} ->
        new_socket =
          new_socket
          |> put_flash(:error, "Database failed with #{reason}.")
          |> stream(:superheroes, [])

        {:ok, new_socket}
    end
  end

  @impl true
  def handle_event("create", _params, socket) do
    superhero_id = UUID.uuid4()

    case SuperheroApi.start(superhero_id) do
      {:ok, _pid} ->
        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to create superhero: #{superhero_id} due to #{inspect(reason)}")

        new_socket =
          socket |> put_flash(:error, "Failed to create superhero: #{superhero_id}.")

        {:noreply, new_socket}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case SuperheroApi.stop(id) do
      {:ok, _} ->
        SuperheroStore.delete_superhero(id)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to delete superhero #{id} #{inspect(reason)}.")

        new_socket =
          socket |> put_flash(:error, "Failed to delete superhero #{id}.")

        {:noreply, new_socket}
    end
  end

  def handle_event("stop_node", %{"node" => node_name}, socket) do
    find_node = Enum.find(Node.list(), fn node -> Atom.to_string(node) == node_name end)

    case find_node do
      nil ->
        Logger.error("Node not found: #{node_name}")

      node ->
        case :rpc.call(node, Dispatch.Application, :shutdown, []) do
          {:badrpc, reason} ->
            Logger.error("RPC failed: #{inspect(reason)}")

          result ->
            Logger.info("RPC succeeded: #{inspect(result)}")
        end
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

    new_socket =
      socket
      |> assign(:node_list, Node.list())

    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:nodedown, node}, socket) do
    Logger.info("Node left the cluster: #{inspect(node)}")

    new_socket =
      socket
      |> assign(:node_list, Node.list())

    {:noreply, new_socket}
  end
end
