defmodule Dispatch.Hero do
  use Ash.Domain

  resources do
    resource Dispatch.Superhero.Resource do
      define(:get_superhero, action: :by_id, args: [:id])
      define(:list_superheroes, action: :list_all)
      define(:create_superhero, action: :create)
      define(:update_superhero, action: :update)
      define(:delete_superhero, action: :destroy)
    end
  end
end
