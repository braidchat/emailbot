defmodule BraidMail.Schemas.Thread do
  @moduledoc """
  DB schema for the threads that correspond to emails
  """
  use Ecto.Schema

  schema "threads" do
    field :braid_id
    field :gmail_id
    field :status
  end
end

defmodule BraidMail.Schemas.User do
  @moduledoc """
  DB schema for relating braid users & gmail api tokens
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :braid_id
    field :gmail_token
    field :gmail_refresh_token
  end

  def changeset(user, params) do
    user
    |> cast(params, [:braid_id, :gmail_token, :gmail_refresh_token])
  end
end
