defmodule MissionControl.Superhero.RaftActions do
  @moduledoc """
  Raft-based storage implementation for Superhero resource actions.

  Implements manual actions that interact with the distributed Raft cluster
  for persistent storage with optimistic locking.
  """

  use Ash.Resource.ManualRead
  use Ash.Resource.ManualCreate
  use Ash.Resource.ManualUpdate
  use Ash.Resource.ManualDestroy

  require Logger

  alias MissionControl.RaftStore

  @cluster_name :dispatch_cluster

  @impl true
  def read(query, _data_layer_query, _opts, _context) do
    cond do
      Map.has_key?(query.arguments, :id) ->
        read_by_id(query.arguments.id)

      true ->
        read_all()
    end
  end

  defp read_by_id(id) do
    case MissionControl.Store.SuperheroStore.get_superhero(id) do
      {:ok, hero} ->
        ash_record = struct!(MissionControl.Superhero, hero)
        {:ok, [ash_record]}

      {:error, _} ->
        {:ok, []}
    end
  end

  defp read_all do
    case MissionControl.Store.SuperheroStore.get_all_superheroes() do
      {:ok, heroes} ->
        ash_records =
          Enum.map(heroes, fn hero ->
            struct!(MissionControl.Superhero, hero)
          end)

        {:ok, ash_records}

      {:error, _reason} ->
        {:ok, []}
    end
  end

  @impl true
  def create(changeset, _opts, _context) do
    hero = changeset.attributes

    Logger.debug("Creating superhero with attrs: #{inspect(hero)}")

    case RaftStore.dirty_write(@cluster_name, hero.id, hero) do
      {:ok, _} ->
        ash_record = struct!(MissionControl.Superhero, hero)
        {:ok, ash_record}

      error ->
        error
    end
  end

  @impl true
  def update(changeset, _opts, _context) do
    expected_map =
      Map.from_struct(changeset.data)
      |> Map.take(Ash.Resource.Info.attribute_names(MissionControl.Superhero))

    new_map = Map.merge(expected_map, changeset.attributes)

    case RaftStore.write(@cluster_name, new_map.id, expected_map, new_map) do
      {:ok, _} ->
        Logger.debug("Update successful for #{new_map.id}")
        ash_record = struct!(MissionControl.Superhero, new_map)
        {:ok, ash_record}

      {:error, :not_match, current_value} ->
        Logger.warning("Optimistic lock failed for #{new_map.id}")
        ash_current = struct!(MissionControl.Superhero, current_value)

        {:error,
         Ash.Error.to_ash_error("Conflict: superhero was updated by another node",
           vars: [current_value: ash_current]
         )}

      error ->
        Logger.error("Update error for #{new_map.id}: #{inspect(error)}")
        error
    end
  end

  @impl true
  def destroy(changeset, _opts, _context) do
    superhero_id = changeset.data.id

    case RaftStore.delete(@cluster_name, superhero_id) do
      {:ok, _} ->
        Logger.debug("Delete successful for #{superhero_id}")
        {:ok, changeset.data}

      error ->
        Logger.error("Delete error for #{superhero_id}: #{inspect(error)}")
        error
    end
  end
end
