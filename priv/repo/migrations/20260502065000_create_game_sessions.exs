defmodule ArchaeologyRush.Repo.Migrations.CreateGameSessions do
  use Ecto.Migration

  def change do
    create table(:game_sessions) do
      add :max_turns, :integer, null: false
      add :target_important_artifacts, :integer, null: false
      add :max_record_misses, :integer, null: false
      add :record_misses, :integer, null: false
      add :final_report_complete, :boolean, null: false, default: false

      add :turn, :integer, null: false
      add :actions_per_turn, :integer, null: false
      add :actions_left, :integer, null: false
      add :score, :integer, null: false
      add :tool_durability, :integer, null: false
      add :next_artifact_id, :integer, null: false

      add :turn_dig_counts_json, :text, null: false
      add :cell_progress_json, :text, null: false
      add :mixed_layers_json, :text, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
