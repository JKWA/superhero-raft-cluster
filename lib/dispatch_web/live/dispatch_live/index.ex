defmodule DispatchWeb.DispatchLive.Index do
  use DispatchWeb, :live_view
  alias Dispatch.Store
  alias Phoenix.PubSub

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(Dispatch.PubSub, Store.PubSub.topic())
    :net_kernel.monitor_nodes(true, [])

    new_socket =
      socket
      |> assign(:city_name, Application.get_env(:dispatch, :city_name))
      |> assign(:node_list, Node.list())

    case Dispatch.Hero.list_superheroes() do
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

  @impl true
  def handle_event("create", _params, socket) do
    superhero_id = UUID.uuid4()

    superhero_attrs = %{
      id: superhero_id,
      name: Dispatch.Superhero.Factory.generate_name()
    }

    case Dispatch.Hero.create_superhero(superhero_attrs) do
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
    # First get the superhero, then delete via Ash (also stops GenServer via after_action hook)
    case Dispatch.Hero.get_superhero(id) do
      {:ok, [superhero]} ->
        case Dispatch.Hero.delete_superhero(superhero) do
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
