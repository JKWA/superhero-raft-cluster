defmodule MissionControl.Superhero.Resource do
  @moduledoc """
  Ash resource for Superhero with Raft-based distributed storage.

  This resource provides CRUD operations for superheroes stored in a
  distributed Raft cluster. All operations use manual actions that interact
  with the underlying RaftStore for distributed consensus.

  Side effects (GenServer lifecycle) are managed via after_action hooks:
  - Creating a superhero starts its GenServer process
  - Deleting a superhero stops its GenServer process
  """
  use Ash.Resource,
    domain: MissionControl,
    data_layer: Ash.DataLayer.Simple

  attributes do
    attribute :id, :string do
      description("Unique identifier for the superhero")
      allow_nil?(false)
      primary_key?(true)
    end

    attribute :name, :string do
      description("Superhero name (e.g., 'Super Batman')")
      allow_nil?(false)
      constraints(min_length: 3, max_length: 100)
    end

    attribute :node, :atom do
      description("Erlang node where the superhero's GenServer is running")
      allow_nil?(false)
      default(:none)
    end

    attribute :is_patrolling, :boolean do
      description("Whether the superhero is currently patrolling")
      allow_nil?(false)
      default(false)
    end

    attribute :fights_won, :integer do
      description("Number of fights won")
      allow_nil?(false)
      constraints(min: 0)
      default(0)
    end

    attribute :fights_lost, :integer do
      description("Number of fights lost")
      allow_nil?(false)
      constraints(min: 0)
      default(0)
    end

    attribute :health, :integer do
      description("Current health points (0-100)")
      allow_nil?(false)
      constraints(min: 0, max: 100)
      default(100)
    end
  end

  calculations do
    calculate :total_fights, :integer, expr(fights_won + fights_lost) do
      description("Total number of fights (won + lost)")
    end

    calculate :win_rate, :float do
      description("Win rate as a percentage (0.0-1.0)")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          total = record.fights_won + record.fights_lost

          rate =
            if total > 0 do
              record.fights_won / total
            else
              0.0
            end

          {record, rate}
        end)
      end)
    end

    calculate :is_healthy, :boolean, expr(health > 50) do
      description("Whether the superhero is in good health (>50 HP)")
    end
  end

  actions do
    read :by_id do
      description("Get a superhero by ID")
      argument(:id, :string, allow_nil?: false)
      manual(MissionControl.Superhero.ManualActions)
    end

    read :list_all do
      description("List all superheroes across the cluster")
      manual(MissionControl.Superhero.ManualActions)
    end

    create :create do
      description("Create a new superhero and start its GenServer")
      accept([:id, :name, :node, :is_patrolling, :fights_won, :fights_lost, :health])
      manual(MissionControl.Superhero.ManualActions)

      # Start the GenServer after successful creation
      change(
        after_action(fn _changeset, superhero, _context ->
          MissionControl.Superhero.Changes.StartGenserver.start(superhero)
        end)
      )
    end

    update :update do
      description("Update superhero attributes with optimistic locking")
      primary?(true)
      accept([:name, :node, :is_patrolling, :fights_won, :fights_lost, :health])
      manual(MissionControl.Superhero.ManualActions)

      # Warn when health is critically low
      change(MissionControl.Superhero.Changes.HealthWarning)
    end

    destroy :destroy do
      description("Delete a superhero and stop its GenServer")
      primary?(true)
      manual(MissionControl.Superhero.ManualActions)

      # Stop the GenServer after successful deletion
      change(
        after_action(fn _changeset, superhero, _context ->
          MissionControl.Superhero.Changes.StopGenserver.stop(superhero)
        end)
      )
    end
  end
end
