defmodule Dispatch.Superhero.Factory do
  @moduledoc """
  Factory for generating superhero data.
  """

  @doc """
  Generates a new superhero struct with random name and default values.

  Note: This function is deprecated. Use Ash to create superheroes instead.
  This is kept only for backwards compatibility.
  """
  def build_new_superhero(id) do
    %{
      id: id,
      name: generate_name(),
      node: :none,
      is_patrolling: false,
      fights_won: 0,
      fights_lost: 0,
      health: 100
    }
  end

  @doc """
  Generates a random superhero name using Faker.
  """
  def generate_name do
    "#{Faker.Superhero.prefix()} #{Faker.Superhero.name()}"
  end
end
