defmodule ArchaeologyRush.RepoCaseTest do
  use ArchaeologyRush.RepoCase, async: false

  alias ArchaeologyRush.Artifact

  describe "RepoCase" do
    test "starts the repo only for database-backed tests" do
      assert Process.whereis(ArchaeologyRush.Repo) != nil

      assert fetch_all!("SELECT 1") == [[1]]
    end

    test "works with the artifact schema and migration" do
      migrations_path = Path.expand("../priv/repo/migrations", __DIR__)
      File.rm_rf!(Application.fetch_env!(:archaeology_rush, ArchaeologyRush.Repo)[:database])

      assert {:ok, _, _} =
               Ecto.Migrator.with_repo(Repo, fn repo ->
                 Ecto.Migrator.run(repo, migrations_path, :up, all: true)
               end)

      assert table_exists?("artifacts")

      changeset =
        Artifact.changeset(%Artifact{}, %{
          name: "Jar Rim",
          layer: "Layer II",
          notes: "Surface-treated sherd"
        })

      assert {:ok, %Artifact{} = artifact} = Repo.insert(changeset)
      assert artifact.name == "Jar Rim"
      assert artifact.layer == "Layer II"

      assert fetch_one!("SELECT name, layer, notes FROM artifacts LIMIT 1") == [
               "Jar Rim",
               "Layer II",
               "Surface-treated sherd"
             ]

      assert count!("artifacts") == 1
    end
  end
end
