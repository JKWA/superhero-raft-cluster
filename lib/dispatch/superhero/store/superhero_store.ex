defmodule Dispatch.Store.SuperheroStore do
  alias Dispatch.{Superhero, RaftStore}
  require Logger

  @cluster_name :dispatch_cluster

  def upsert_superhero(
        %Superhero{id: id} = expected_superhero,
        %Superhero{} = new_superhero
      ) do
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
