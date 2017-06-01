defmodule BraidMail.Repo.Migrations.CreateTables do
  use Ecto.Migration

  def change do
    create table(:users, engine: :set) do
      add :braid_id, :string
      add :gmail_token, :string
    end

    create table(:threads, engine: :set) do
      add :braid_id, :string
      add :gmail_id, :string
      add :status, :string
    end
  end
end
