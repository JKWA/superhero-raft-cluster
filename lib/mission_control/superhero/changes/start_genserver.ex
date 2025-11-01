defmodule MissionControl.Superhero.Changes.StartSuperhero do
  @moduledoc """
  Starts the SuperheroServer GenServer after successful superhero creation.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, superhero ->
      case MissionControl.SuperheroApi.start(superhero.id) do
        {:ok, _pid} ->
          {:ok, superhero}

        {:error, reason} ->
          {:error, Ash.Error.to_ash_error("Failed to start GenServer: #{inspect(reason)}")}
      end
    end)
  end
end
