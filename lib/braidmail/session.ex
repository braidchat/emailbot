defmodule BraidMail.Session do
  @moduledoc """
  Agent-based session storage
  """

  def start_link() do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc "Store the given value under the key"
  def store(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end

  @doc """
  Return the value stored at `key`, removing the stored value from the store
  """
  def pop(key) do
    Agent.get_and_update(__MODULE__, &Map.pop(&1, key))
  end
end
