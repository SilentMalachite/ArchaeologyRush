defmodule ArchaeologyRush.Repo.Migrations.CreateArtifacts do
  use Ecto.Migration

  def change do
    create table(:artifacts) do
      add :name, :text, null: false
      add :layer, :text, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end
  end
end
