defmodule BraidMail.Repo.Migrations.AddThreadReplyToColumn do
  use Ecto.Migration

  def change do
    alter table(:threads) do
      add :reply_to, :string
    end
  end
end
