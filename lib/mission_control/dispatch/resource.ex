defmodule MissionControl.Dispatch.Resource do
  @moduledoc """
  Ash resource for Dispatch (cluster nodes).

  This resource models ephemeral/derived data - dispatch centers are not stored
  in Raft or any persistent storage. They are discovered at runtime via Node.list().

  Key differences from Superhero resource:
  - No persistent storage (ephemeral data from Node.list())
  - No create/update actions (nodes auto-join/leave via Horde)
  - Destroy action triggers side effect (RPC shutdown) rather than storage deletion
  - All data is derived/calculated at read time
  """
  use Ash.Resource,
    domain: MissionControl,
    data_layer: Ash.DataLayer.Simple

  attributes do
    attribute :node, :atom do
      description("Erlang node name (e.g., :gotham@127.0.0.1)")
      allow_nil?(false)
      primary_key?(true)
    end

    attribute :city_name, :string do
      description("City name for this dispatch center (from node's Application config)")
      allow_nil?(false)
      default("Unknown")
    end

    attribute :status, :atom do
      description("Node status (:up or :down)")
      allow_nil?(false)
      default(:up)
    end
  end

  actions do
    read :list_all do
      description("List all dispatch centers in the cluster")
      manual(MissionControl.Dispatch.ManualActions)
    end

    read :by_node do
      description("Get a specific dispatch center by node name")
      argument(:node, :atom, allow_nil?: false)
      manual(MissionControl.Dispatch.ManualActions)
    end

    destroy :shutdown do
      description("Shutdown a dispatch center (triggers RPC call to stop the node)")
      primary?(true)
      manual(MissionControl.Dispatch.ManualActions)
    end
  end
end
