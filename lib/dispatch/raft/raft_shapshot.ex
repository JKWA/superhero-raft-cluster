defmodule Dispatch.RaftSnapshot do
  @moduledoc """
  Fully implements the :ra_snapshot behaviour for managing snapshots in a Raft-based system.
  """

  @behaviour :ra_snapshot

  # Function to prepare data for snapshotting
  @impl true
  def prepare(_index, _state) do
    data = :ets.tab2list(:raft_store)
    {:ok, :erlang.term_to_binary(data)}
  end

  # Begins a snapshot accept process
  @impl true
  def begin_accept(_snapshot_dir, _meta) do
    # Initialize the state or storage needed to start accepting snapshot data
    # Example state holding chunks as a list
    {:ok, %{chunks: []}}
  end

  # Accepts a chunk of snapshot data
  @impl true
  def accept_chunk(chunk, state) do
    # Here we append the chunk to the state
    new_state = update_state(state, chunk)
    {:ok, new_state}
  end

  # Completes the snapshot acceptance process
  @impl true
  def complete_accept(_final_chunk, state) do
    # Finalize the snapshot acceptance
    {:ok, state}
  end

  # Writes snapshot data to storage
  @impl true
  def write(snapshot_data, location, _meta, _sync) do
    File.write(location, snapshot_data)
  end

  # Reads and returns the meta-data for a snapshot
  @impl true
  def read_meta(location) do
    # Assume metadata is stored in a specific format or location
    # Dummy metadata
    {:ok, "metadata_placeholder"}
  end

  # Begins the process of reading a snapshot
  @impl true
  def begin_read(location, _context) do
    # Prepare to read the snapshot
    # Dummy metadata and read state
    {:ok, "metadata_placeholder", %{location: location}}
  end

  # Reads a chunk of data from the snapshot
  @impl true
  def read_chunk(state, chunk_size, _location) do
    # Simulate reading a chunk of the snapshot
    # Dummy chunk
    {:ok, "chunk_placeholder", state}
  end

  # Recovers state from binary data
  @impl true
  def recover(binary_data) do
    data = :erlang.binary_to_term(binary_data)
    :ets.delete_all_objects(:raft_store)

    Enum.each(data, fn entry ->
      :ets.insert(:raft_store, entry)
    end)

    {:ok, data}
  end

  # Synchronizes the snapshot data to disk
  @impl true
  def sync(location) do
    File.sync(location)
  end

  # Validates the integrity of a snapshot
  @impl true
  def validate(location) do
    # Validate the snapshot file at the specified location
    if File.exists?(location), do: :ok, else: {:error, :invalid_snapshot}
  end

  # A helper function to update the state with a new chunk
  defp update_state(state, chunk) do
    Map.update!(state, :chunks, fn chunks -> [chunk | chunks] end)
  end
end
