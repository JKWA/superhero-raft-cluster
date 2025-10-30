defmodule MissionControl.SuperheroRegistryHandler do
  require Logger
  alias MissionControl.{SuperheroRegistry}
  alias Horde.{Registry}

  def get_all_superheroes do
    Registry.select(SuperheroRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def get_pid_for_superhero(id) do
    case Registry.lookup(SuperheroRegistry, id) do
      [{pid, _}] ->
        pid

      _ ->
        nil
    end
  end

  def get_node_for_superhero(id) do
    case Registry.lookup(SuperheroRegistry, id) do
      [{pid, _}] ->
        node(pid)

      _ ->
        :unknown
    end
  end
end
