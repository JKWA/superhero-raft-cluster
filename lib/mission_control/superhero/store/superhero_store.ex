defmodule MissionControl.Store.SuperheroStore do
  alias MissionControl.RaftStore
  require Logger

  @cluster_name :dispatch_cluster

  def upsert_superhero(expected_superhero, new_superhero)
      when is_map(expected_superhero) and is_map(new_superhero) do
    id = expected_superhero.id
    RaftStore.write(@cluster_name, id, expected_superhero, new_superhero)
  end

  def get_superhero(id) do
    RaftStore.read(@cluster_name, id)
  end

  def get_all_superheroes do
    superheroes =
      RaftStore.read_all(@cluster_name)

    superheroes
  end

  def delete_superhero(id) do
    RaftStore.delete(@cluster_name, id)
  end
end
