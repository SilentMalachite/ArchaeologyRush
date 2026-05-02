defmodule ArchaeologyRush.Repo.Migrations.CreateTurnLogs do
  use Ecto.Migration

  def change do
    create table(:turn_logs) do
      add :game_session_id, references(:game_sessions, on_delete: :delete_all), null: false
      add :turn, :integer, null: false
      add :action, :text, null: false
      add :payload_json, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:turn_logs, [:game_session_id])
  end
end
