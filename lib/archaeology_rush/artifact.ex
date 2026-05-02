defmodule ArchaeologyRush.Artifact do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias ArchaeologyRush.SavedSession

  schema "artifacts" do
    belongs_to :game_session, SavedSession
    field :game_artifact_id, :integer
    field :name, :string
    field :layer, :string
    field :notes, :string
    field :kind, :string
    field :quality, :string
    field :status, :string
    field :coordinate_row, :integer
    field :coordinate_col, :integer
    field :depth, :integer
    field :layer_id, :string
    field :discovered_turn, :integer
    field :operator_note, :string

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

  @spec game_changeset(t(), attrs()) :: Ecto.Changeset.t()
  def game_changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [
      :game_session_id,
      :game_artifact_id,
      :name,
      :layer,
      :notes,
      :kind,
      :quality,
      :status,
      :coordinate_row,
      :coordinate_col,
      :depth,
      :layer_id,
      :discovered_turn,
      :operator_note
    ])
    |> validate_required([
      :game_artifact_id,
      :kind,
      :quality,
      :status,
      :coordinate_row,
      :coordinate_col,
      :depth,
      :layer_id,
      :discovered_turn
    ])
    |> validate_number(:game_artifact_id, greater_than: 0)
    |> validate_number(:coordinate_row, greater_than_or_equal_to: 0)
    |> validate_number(:coordinate_col, greater_than_or_equal_to: 0)
    |> validate_number(:depth, greater_than_or_equal_to: 0)
    |> validate_number(:discovered_turn, greater_than: 0)
    |> validate_inclusion(:kind, ~w(pottery_shard stone_tool bone_fragment feature_mark))
    |> validate_inclusion(:quality, ~w(poor fair good excellent))
    |> validate_inclusion(:status, ~w(discovered on_hold cataloged recovered))
  end
end
