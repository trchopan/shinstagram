defmodule Shinstagram.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:status, :text)
      add(:event, :string)

      timestamps()
    end
  end
end
