defmodule MissionControl.Dispatch.ManualActions do
  @moduledoc """
  Manual actions for Dispatch resource.

  Wraps existing node operations (Node.list(), :rpc.call()) with Ash's action system.
  Does NOT rewrite the logic - just calls MissionControl.Dispatch.Ops functions.
  """

  use Ash.Resource.ManualRead
  use Ash.Resource.ManualDestroy

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

    case MissionControl.Dispatch.Ops.shutdown(dispatch_center.node) do
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

  # Private functions

  defp read_all do
    # Call existing Ops function - no rewrite!
    centers = MissionControl.Dispatch.Ops.list_all()

    # Convert plain maps to Ash Resource structs
    ash_records =
      Enum.map(centers, fn center ->
        struct!(MissionControl.Dispatch.Resource, center)
      end)

    {:ok, ash_records}
  end

  defp read_by_node(query) do
    node_arg = Ash.Query.get_argument(query, :node)

    case MissionControl.Dispatch.Ops.get_info(node_arg) do
      nil ->
        {:ok, []}

      center ->
        ash_record = struct!(MissionControl.Dispatch.Resource, center)
        {:ok, [ash_record]}
    end
  end
end
