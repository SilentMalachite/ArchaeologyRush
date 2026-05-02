defmodule ArchaeologyRush.SavedSession do
  @moduledoc """
  永続化された発掘セッションのスナップショットです。
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ArchaeologyRush.{Artifact, TurnLog}

  schema "game_sessions" do
    field :max_turns, :integer
    field :target_important_artifacts, :integer
    field :max_record_misses, :integer
    field :record_misses, :integer
    field :final_report_complete, :boolean, default: false

    field :turn, :integer
    field :actions_per_turn, :integer
    field :actions_left, :integer
    field :score, :integer
    field :tool_durability, :integer
    field :next_artifact_id, :integer

    field :turn_dig_counts_json, :string
    field :cell_progress_json, :string
    field :mixed_layers_json, :string

    has_many :artifacts, Artifact, foreign_key: :game_session_id
    has_many :turn_logs, TurnLog, foreign_key: :game_session_id

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}
  @type attrs :: %{optional(atom()) => term()}

  @required_fields ~w(
    max_turns
    target_important_artifacts
    max_record_misses
    record_misses
    final_report_complete
    turn
    actions_per_turn
    actions_left
    score
    tool_durability
    next_artifact_id
    turn_dig_counts_json
    cell_progress_json
    mixed_layers_json
  )a

  @spec changeset(t(), attrs()) :: Ecto.Changeset.t()
  def changeset(saved_session, attrs) do
    saved_session
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_number(:max_turns, greater_than: 0)
    |> validate_number(:target_important_artifacts, greater_than_or_equal_to: 0)
    |> validate_number(:max_record_misses, greater_than_or_equal_to: 0)
    |> validate_number(:record_misses, greater_than_or_equal_to: 0)
    |> validate_number(:turn, greater_than: 0)
    |> validate_number(:actions_per_turn, greater_than: 0)
    |> validate_number(:actions_left, greater_than_or_equal_to: 0)
    |> validate_number(:tool_durability, greater_than_or_equal_to: 0)
    |> validate_number(:next_artifact_id, greater_than: 0)
  end
end
