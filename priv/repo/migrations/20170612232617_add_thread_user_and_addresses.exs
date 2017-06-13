defmodule BraidMail.Repo.Migrations.AddThreadUserAndAddresses do
  use Ecto.Migration

  def change do
    alter table(:threads) do
      add :user_id, :string
      add :to, :string
    end
  end
end
