defmodule MissionControl.Superhero.ManualActions do
  @moduledoc """
  Manual action implementations for Superhero resource.
  """

  use Ash.Resource.ManualRead
  use Ash.Resource.ManualCreate
  use Ash.Resource.ManualUpdate
  use Ash.Resource.ManualDestroy

  alias MissionControl.RaftStore

  @cluster_name :dispatch_cluster

  @impl true
  def read(query, _data_layer_query, _opts, _context) do
    # Handle different read actions based on arguments
    cond do
      # :by_id action has an :id argument
      Map.has_key?(query.arguments, :id) ->
        read_by_id(query.arguments.id)

      # :list_all action has no arguments
      true ->
        read_all()
    end
  end

  defp read_by_id(id) do
    case MissionControl.Store.SuperheroStore.get_superhero(id) do
      {:ok, hero} ->
        # hero is a plain map from Raft - convert to Ash Resource struct
        ash_record = struct!(MissionControl.Superhero.Resource, hero)
        {:ok, [ash_record]}

      {:error, _} ->
        {:ok, []}
    end
  end

  defp read_all do
    case MissionControl.Store.SuperheroStore.get_all_superheroes() do
      {:ok, heroes} ->
        # heroes are plain maps from Raft - convert to Ash Resource structs
        ash_records =
          Enum.map(heroes, fn hero ->
            struct!(MissionControl.Superhero.Resource, hero)
          end)

        {:ok, ash_records}

      {:error, _reason} ->
        {:ok, []}
    end
  end

  @impl true
  def create(changeset, _opts, _context) do
    require Logger

    # Get attributes as plain map for Raft storage
    attrs = changeset.attributes
    hero_map = Map.new(attrs)

    Logger.debug("Creating superhero with attrs: #{inspect(hero_map)}")

    # Store plain map in Raft (no struct, no metadata)
    case RaftStore.dirty_write(@cluster_name, hero_map.id, hero_map) do
      {:ok, _} ->
        # Return as Ash Resource struct
        ash_record = struct!(MissionControl.Superhero.Resource, hero_map)
        {:ok, ash_record}

      error ->
        error
    end
  end

  @impl true
  def update(changeset, _opts, _context) do
    require Logger

    # Get the original superhero as plain map (only actual attributes, not calculations/metadata)
    expected_map =
      Map.from_struct(changeset.data)
      |> Map.take([:id, :name, :node, :is_patrolling, :fights_won, :fights_lost, :health])

    # Build the new superhero map with updated attributes
    new_map = Map.merge(expected_map, changeset.attributes)

    Logger.debug("Update attempt for #{new_map.id}")
    Logger.debug("Expected: #{inspect(expected_map)}")
    Logger.debug("New: #{inspect(new_map)}")

    # Use conditional write (optimistic locking) - store as plain map
    case RaftStore.write(@cluster_name, new_map.id, expected_map, new_map) do
      {:ok, _} ->
        Logger.debug("Update successful for #{new_map.id}")
        # Return as Ash Resource struct
        ash_record = struct!(MissionControl.Superhero.Resource, new_map)
        {:ok, ash_record}

      {:error, :not_match, current_value} ->
        Logger.warning("Optimistic lock failed for #{new_map.id}")
        Logger.warning("Expected: #{inspect(expected_map)}")
        Logger.warning("In Raft:  #{inspect(current_value)}")
        # Another node updated it - return the current value as Ash Resource
        ash_current = struct!(MissionControl.Superhero.Resource, current_value)

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
        {:ok, changeset.data}

      error ->
        error
    end
  end
end
