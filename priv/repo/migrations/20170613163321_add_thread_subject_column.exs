defmodule BraidMail.Repo.Migrations.AddThreadSubjectColumn do
  use Ecto.Migration

  def change do
    alter table(:threads) do
      add :subject, :string
    end
  end
end
