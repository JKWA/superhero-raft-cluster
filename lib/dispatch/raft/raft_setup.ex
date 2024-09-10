defmodule Dispatch.RaftSetup do
  use GenServer
  require Logger
  alias Dispatch.RaftStore
  @cluster_name :dispatch_cluster

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    :ra.start()

    nodes = Keyword.get(opts, :nodes, [])

    machine = {:module, RaftStore, %{}}
    ids = Enum.map(nodes, fn node -> {@cluster_name, node} end)

    case :ra.start_cluster(:default, @cluster_name, machine, ids) do
      {:ok, started, not_started} ->
        Logger.info(
          "Node #{Node.self()} successfully started the Raft cluster. #{inspect(started)}, #{inspect(not_started)}"
        )

        {:ok, %{nodes: nodes}}

      abort ->
        Logger.error("Failed to start Raft cluster, reason: #{inspect(abort)}")
        {:ok, %{nodes: nodes}}
    end

    {:ok, %{nodes: nodes}}
  end
end
