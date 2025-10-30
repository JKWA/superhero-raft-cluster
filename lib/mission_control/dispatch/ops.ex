defmodule MissionControl.Dispatch.Ops do
  @moduledoc """
  Operations for managing dispatch centers (nodes) in the cluster.
  """

  require Logger

  @doc """
  Lists all dispatch centers in the cluster (all connected nodes + current node).

  Returns a list of maps with node information enriched with domain data.
  """
  def list_all do
    all_nodes = [node() | Node.list()]

    Enum.map(all_nodes, fn node_name ->
      %{
        node: node_name,
        city_name: get_city_name(node_name),
        status: :up
      }
    end)
  end

  @doc """
  Gets information about a specific dispatch center.

  Returns nil if the node is not in the cluster.
  """
  def get_info(node_name) when is_atom(node_name) do
    all_nodes = [node() | Node.list()]

    if node_name in all_nodes do
      %{
        node: node_name,
        city_name: get_city_name(node_name),
        status: :up
      }
    else
      nil
    end
  end

  def get_info(node_name) when is_binary(node_name) do
    case string_to_node(node_name) do
      {:ok, node} -> get_info(node)
      :error -> nil
    end
  end

  @doc """
  Shuts down a dispatch center by node name (string or atom).

  Makes an RPC call to the target node to initiate shutdown.
  Returns {:ok, result} on success, {:error, reason} on failure.
  """
  def shutdown(node_name) when is_binary(node_name) do
    case string_to_node(node_name) do
      {:ok, node} ->
        shutdown_node(node)

      :error ->
        Logger.error("Node not found: #{node_name}")
        {:error, :node_not_found}
    end
  end

  def shutdown(node_name) when is_atom(node_name) do
    shutdown_node(node_name)
  end

  defp shutdown_node(node) do
    case :rpc.call(node, MissionControl.Application, :shutdown, []) do
      {:badrpc, reason} ->
        Logger.error("RPC failed for node #{node}: #{inspect(reason)}")
        {:error, {:rpc_failed, reason}}

      result ->
        Logger.info("RPC succeeded for node #{node}: #{inspect(result)}")
        {:ok, result}
    end
  end

  defp string_to_node(node_string) do
    all_nodes = [node() | Node.list()]
    found = Enum.find(all_nodes, fn node -> Atom.to_string(node) == node_string end)

    if found, do: {:ok, found}, else: :error
  end

  defp get_city_name(node_name) do
    if node_name == node() do
      Application.get_env(:dispatch, :city_name, "Unknown")
    else
      case :rpc.call(node_name, Application, :get_env, [:dispatch, :city_name, "Unknown"]) do
        {:badrpc, _reason} -> "Unknown"
        city -> city
      end
    end
  end
end
