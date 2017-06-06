defmodule BraidMail.Repo.Migrations.AddRefreshTokenColumn do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :gmail_refresh_token, :string
    end
  end
end
