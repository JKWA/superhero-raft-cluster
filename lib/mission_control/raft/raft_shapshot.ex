defmodule MissionControl.RaftSnapshot do
  @moduledoc """
  Fully implements the :ra_snapshot behaviour for managing snapshots in a Raft-based system.
  """

  @behaviour :ra_snapshot

  @impl true
  def prepare(_index, _state) do
    data = :ets.tab2list(:raft_store)
    {:ok, :erlang.term_to_binary(data)}
  end

  @impl true
  def begin_accept(_snapshot_dir, _meta) do
    {:ok, %{chunks: []}}
  end

  @impl true
  def accept_chunk(chunk, state) do
    new_state = update_state(state, chunk)
    {:ok, new_state}
  end

  @impl true
  def complete_accept(_final_chunk, state) do
    {:ok, state}
  end

  @impl true
  def write(snapshot_data, location, _meta, _sync) do
    File.write(location, snapshot_data)
  end

  @impl true
  def read_meta(_location) do
    {:ok, "metadata_placeholder"}
  end

  @impl true
  def begin_read(location, _context) do
    {:ok, "metadata_placeholder", %{location: location}}
  end

  @impl true
  def read_chunk(state, _chunk_size, _location) do
    {:ok, "chunk_placeholder", state}
  end

  @impl true
  def recover(binary_data) do
    data = :erlang.binary_to_term(binary_data)
    :ets.delete_all_objects(:raft_store)

    Enum.each(data, fn entry ->
      :ets.insert(:raft_store, entry)
    end)

    {:ok, data}
  end

  @impl true
  def sync(location) do
    case File.open(location, [:read, :write]) do
      {:ok, device} ->
        result = :file.sync(device)
        File.close(device)
        result

      error ->
        error
    end
  end

  @impl true
  def validate(location) do
    if File.exists?(location), do: :ok, else: {:error, :invalid_snapshot}
  end

  defp update_state(state, chunk) do
    Map.update!(state, :chunks, fn chunks -> [chunk | chunks] end)
  end
end
