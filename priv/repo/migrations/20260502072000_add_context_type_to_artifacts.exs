defmodule ArchaeologyRush.Repo.Migrations.AddContextTypeToArtifacts do
  use Ecto.Migration

  def change do
    alter table(:artifacts) do
      add :context_type, :text
    end
  end
end
