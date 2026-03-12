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

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
