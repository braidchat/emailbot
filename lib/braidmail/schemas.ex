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

  schema "users" do
    field :braid_id
    field :gmail_token
  end
end
