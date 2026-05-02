defmodule ArchaeologyRush.ArtifactTest do
  use ExUnit.Case, async: true

  alias ArchaeologyRush.Artifact

  describe "changeset/2" do
    test "is valid with required attributes" do
      changeset =
        Artifact.changeset(%Artifact{}, %{
          name: "Jar Rim",
          layer: "Layer II",
          notes: "Surface-treated sherd"
        })

      assert changeset.valid?
      assert changeset.errors == []
    end

    test "requires name and layer" do
      changeset = Artifact.changeset(%Artifact{}, %{notes: "Unlabeled find"})

      refute changeset.valid?

      assert errors_on(changeset) == %{
               layer: ["can't be blank"],
               name: ["can't be blank"]
             }
    end
  end

  describe "game_changeset/2" do
    test "is valid with game artifact attributes" do
      changeset =
        Artifact.game_changeset(%Artifact{}, %{
          game_artifact_id: 1,
          kind: "pottery_shard",
          quality: "good",
          status: "discovered",
          coordinate_row: 1,
          coordinate_col: 2,
          depth: 3,
          layer_id: "lower",
          discovered_turn: 4,
          context_type: "feature_inside",
          operator_note: "rim fragment near grid edge"
        })

      assert changeset.valid?
      assert changeset.errors == []
    end

    test "requires game artifact fields" do
      changeset = Artifact.game_changeset(%Artifact{}, %{})

      refute changeset.valid?

      assert errors_on(changeset) == %{
               coordinate_col: ["can't be blank"],
               coordinate_row: ["can't be blank"],
               depth: ["can't be blank"],
               discovered_turn: ["can't be blank"],
               game_artifact_id: ["can't be blank"],
               kind: ["can't be blank"],
               layer_id: ["can't be blank"],
               quality: ["can't be blank"],
               status: ["can't be blank"]
             }
    end

    test "rejects unsupported context types" do
      changeset =
        Artifact.game_changeset(%Artifact{}, %{
          game_artifact_id: 1,
          kind: "pottery_shard",
          quality: "good",
          status: "cataloged",
          coordinate_row: 1,
          coordinate_col: 2,
          depth: 3,
          layer_id: "lower",
          discovered_turn: 4,
          context_type: "unknown_context"
        })

      refute changeset.valid?
      assert errors_on(changeset).context_type == ["is invalid"]
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
