defmodule Dispatch.Superhero.Changes.StartGenserver do
  @moduledoc """
  Starts the SuperheroServer GenServer after successful superhero creation.
  """

  def start(superhero) do
    case Dispatch.SuperheroApi.start(superhero.id) do
      {:ok, _pid} ->
        {:ok, superhero}

      {:error, reason} ->
        {:error,
         Ash.Error.to_ash_error(
           "Failed to start GenServer: #{inspect(reason)}"
         )}
    end
  end
end
