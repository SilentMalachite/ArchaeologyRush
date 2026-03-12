defmodule ArchaeologyRush.Artifact do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "artifacts" do
    field :name, :string
    field :layer, :string
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}
  @type attrs :: %{optional(atom()) => term()}

  @spec changeset(t(), attrs()) :: Ecto.Changeset.t()
  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [:name, :layer, :notes])
    |> validate_required([:name, :layer])
  end
end
