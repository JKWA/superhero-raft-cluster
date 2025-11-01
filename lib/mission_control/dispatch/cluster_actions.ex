defmodule MissionControl.Dispatch.ClusterActions do
  @moduledoc """
  Cluster-based discovery implementation for Dispatch resource actions.

  Reads ephemeral cluster state via ClusterService and performs node operations.
  Does not persist data - all state is discovered at runtime.
  """

  use Ash.Resource.ManualRead
  use Ash.Resource.ManualDestroy
  alias MissionControl.Dispatch.ClusterService

  require Logger

  @impl true
  def read(query, _opts, _context, _data_layer_query) do
    case query.action.name do
      :list_all ->
        read_all()

      :by_node ->
        read_by_node(query)

      action ->
        {:error, "Unknown action: #{action}"}
    end
  end

  @impl true
  def destroy(changeset, _opts, _context) do
    dispatch_center = changeset.data

    case ClusterService.shutdown(dispatch_center.node) do
      {:ok, _result} ->
        Logger.info("MissionControl center #{dispatch_center.node} shutdown initiated")
        {:ok, dispatch_center}

      {:error, reason} ->
        Logger.error(
          "Failed to shutdown dispatch center #{dispatch_center.node}: #{inspect(reason)}"
        )

        {:error, "Failed to shutdown node: #{inspect(reason)}"}
    end
  end

  defp read_all do
    centers = ClusterService.list_all()

    ash_records =
      Enum.map(centers, fn center ->
        struct!(MissionControl.Dispatch, center)
      end)

    {:ok, ash_records}
  end

  defp read_by_node(query) do
    node_arg = Ash.Query.get_argument(query, :node)

    case ClusterService.get_info(node_arg) do
      nil ->
        {:ok, []}

      center ->
        ash_record = struct!(MissionControl.Dispatch, center)
        {:ok, [ash_record]}
    end
  end
end
