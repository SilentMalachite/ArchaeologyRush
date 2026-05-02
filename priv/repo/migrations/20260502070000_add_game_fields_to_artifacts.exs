defmodule ArchaeologyRush.Repo.Migrations.AddGameFieldsToArtifacts do
  use Ecto.Migration

  def change do
    alter table(:artifacts) do
      add :game_session_id, references(:game_sessions, on_delete: :delete_all)
      add :game_artifact_id, :integer
      add :kind, :text
      add :quality, :text
      add :status, :text
      add :coordinate_row, :integer
      add :coordinate_col, :integer
      add :depth, :integer
      add :layer_id, :text
      add :discovered_turn, :integer
      add :operator_note, :text
    end

    create index(:artifacts, [:game_session_id])
    create index(:artifacts, [:game_session_id, :game_artifact_id])
  end
end
