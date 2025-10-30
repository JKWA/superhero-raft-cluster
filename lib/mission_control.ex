defmodule MissionControl do
  use Ash.Domain

  resources do
    resource MissionControl.Superhero.Resource do
      define(:get_superhero, action: :by_id, args: [:id])
      define(:list_superheroes, action: :list_all)
      define(:create_superhero, action: :create)
      define(:update_superhero, action: :update)
      define(:delete_superhero, action: :destroy)
    end

    resource MissionControl.Dispatch.Resource do
      define(:get_dispatch_center, action: :by_node, args: [:node])
      define(:list_dispatch_centers, action: :list_all)
      define(:shutdown_dispatch_center, action: :shutdown)
    end
  end
end
