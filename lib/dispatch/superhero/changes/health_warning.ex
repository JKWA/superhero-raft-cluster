defmodule Dispatch.Superhero.Changes.HealthWarning do
  @moduledoc """
  Logs a warning when superhero health drops to critically low levels.
  """
  use Ash.Resource.Change

  require Logger

  @critical_health 20

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :health) do
      health when is_integer(health) and health <= @critical_health ->
        Logger.warning("Health is critically low (#{health}/100)")
        changeset

      _ ->
        changeset
    end
  end
end
