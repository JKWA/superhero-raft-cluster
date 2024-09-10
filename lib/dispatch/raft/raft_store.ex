defmodule Dispatch.RaftStore do
  @behaviour :ra_machine
  require Logger

  defstruct ets_table: nil, index: nil, term: nil

  @impl true
  def init(_config) do
    ets_table = :ets.new(:raft_store, [:set, :public, :named_table])

    %__MODULE__{
      ets_table: ets_table
    }
  end

  def write(cluster_name, key, expected_value, new_value, opts \\ []) do
    defaults = [eq_fun: fn a, b -> a == b end]
    options = Keyword.merge(defaults, opts)

    eq_fun = Keyword.get(options, :eq_fun)

    cmd = {:write, key, expected_value, new_value, eq_fun}

    case :ra.process_command(cluster_name, cmd) do
      {:ok, {{:read, _new_value}, _metadata}, _leader} ->
        {:ok, :written}

      {:ok, {{:error, :not_match, current_value}, _metadata}, _leader} ->
        {:error, :not_match, current_value}

      {:timeout, _} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def dirty_write(cluster_name, key, value) do
    cmd = {:dirty_write, key, value}

    case :ra.process_command(cluster_name, cmd) do
      {:ok, {_index, _term}, _leader_ra_node_id} ->
        {:ok, :written}

      {:timeout, _} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete(cluster_name, key) do
    cmd = {:delete, key}

    case :ra.process_command(cluster_name, cmd) do
      {:ok, {_index, _term}, _leader_ra_node_id} ->
        {:ok, :deleted}

      {:timeout, _} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read(cluster_name, key) do
    fun = fn
      %__MODULE__{ets_table: ets_table} ->
        case :ets.lookup(ets_table, key) do
          [] -> :undefined
          [{_key, value}] -> value
        end
    end

    case :ra.consistent_query(cluster_name, fun) do
      {:ok, :undefined, _leader} ->
        {:error, :not_found}

      {:ok, value, _leader} ->
        {:ok, value}

      {:timeout, _} ->
        Logger.info("Read operation failed because of timeout\n")
        {:error, :timeout}

      {:error, :nodedown} ->
        Logger.info("Read operation failed because node is down\n")
        {:error, :nodedown}

      r ->
        Logger.warning("Unexpected result for read operation: #{inspect(r)}\n")
        {:error, :unexpected_result}
    end
  end

  def read_all(cluster_name) do
    fun = fn
      %__MODULE__{ets_table: ets_table} ->
        :ets.tab2list(ets_table) |> Enum.map(fn {_key, value} -> value end)
    end

    case :ra.consistent_query(cluster_name, fun) do
      {:ok, values, _leader} ->
        {:ok, values}

      {:timeout, _} ->
        {:error, :timeout}

      {:error, :nodedown} ->
        {:error, :nodedown}

      r ->
        Logger.warning("Unexpected result for read_all operation: #{inspect(r)}\n")
        {:error, :unexpected_result}
    end
  end

  @impl true
  def apply(
        metadata,
        {:write, key, expected_value, new_value, equality_fn},
        %__MODULE__{ets_table: ets_table} = state
      ) do
    current_value =
      case :ets.lookup(ets_table, key) do
        [] -> :undefined
        [{_key, value}] -> value
      end

    case current_value do
      :undefined ->
        :ets.insert(ets_table, {key, new_value})

        new_state = %__MODULE__{
          state
          | index: metadata.index,
            term: metadata.term
        }

        {new_state, {{:read, new_value}, %{index: metadata.index, term: metadata.term}},
         update_side_effects(key, new_value)}

      _ ->
        case equality_fn.(current_value, expected_value) do
          true ->
            :ets.insert(ets_table, {key, new_value})

            new_state = %__MODULE__{
              state
              | index: metadata.index,
                term: metadata.term
            }

            {new_state, {{:read, new_value}, %{index: metadata.index, term: metadata.term}},
             update_side_effects(key, new_value)}

          false ->
            {state,
             {{:error, :not_match, current_value}, %{index: metadata.index, term: metadata.term}},
             update_failure_side_effects(key, "Value mismatch", current_value)}
        end
    end
  end

  @impl true
  def apply(metadata, {:dirty_write, key, value}, %__MODULE__{ets_table: ets_table} = state) do
    :ets.insert(ets_table, {key, value})

    new_state = %__MODULE__{
      state
      | index: metadata.index,
        term: metadata.term
    }

    {new_state, {metadata.index, metadata.term}, update_side_effects(key, value)}
  end

  @impl true
  def apply(metadata, {:delete, key}, %__MODULE__{ets_table: ets_table} = state) do
    :ets.delete(ets_table, key)

    new_state = %__MODULE__{
      state
      | index: metadata.index,
        term: metadata.term
    }

    {new_state, {metadata.index, metadata.term}, delete_side_effects(key)}
  end

  defp update_side_effects(key, value) do
    [{:send_msg, {:message_server, node()}, {:key_updated, key, value}, [:cast]}]
  end

  defp delete_side_effects(key) do
    [{:send_msg, {:message_server, node()}, {:key_deleted, key}, [:cast]}]
  end

  defp update_failure_side_effects(key, reason, current_state) do
    [{:send_msg, {:message_server, node()}, {:failure, key, reason, current_state}, [:cast]}]
  end
end
