defmodule BraidMail.Repo.Migrations.AddThreadContent do
  use Ecto.Migration

  def change do
    alter table(:threads) do
      add :content, :string
    end
  end
end
