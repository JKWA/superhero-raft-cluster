defmodule MissionControl.Superhero.Changes.StopGenserver do
  @moduledoc """
  Stops the SuperheroServer GenServer after successful superhero deletion.
  Tolerates :not_found errors (GenServer already stopped).
  """

  def stop(superhero) do
    case MissionControl.SuperheroApi.stop(superhero.id) do
      {:ok, _} ->
        {:ok, superhero}

      {:error, :not_found} ->
        # GenServer already stopped or doesn't exist - that's fine
        {:ok, superhero}

      {:error, reason} ->
        {:error, Ash.Error.to_ash_error("Failed to stop GenServer: #{inspect(reason)}")}
    end
  end
end
