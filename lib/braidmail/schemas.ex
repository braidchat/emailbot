defmodule BraidMail.Schemas.Thread do
  @moduledoc """
  DB schema for the threads that correspond to emails
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "threads" do
    field :braid_id
    field :gmail_id
    field :status
    field :content
    field :user_id
    field :to
    field :subject
  end

  def changeset(thread, params) do
    thread
    |> cast(params, ~w(content subject status)a)
  end

  def append_changeset(%{content: <<>>} = thread, more_content) do
    thread
    |> changeset(%{content: more_content})
  end
  def append_changeset(%{content: content} = thread, more_content) do
    thread
    |> changeset(%{content: content <> "\n" <> more_content})
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
