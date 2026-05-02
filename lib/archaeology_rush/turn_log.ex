defmodule ArchaeologyRush.TurnLog do
  @moduledoc """
  永続化されたターンログです。
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ArchaeologyRush.SavedSession

  schema "turn_logs" do
    belongs_to :game_session, SavedSession

    field :turn, :integer
    field :action, :string
    field :payload_json, :string

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}
  @type attrs :: %{optional(atom()) => term()}

  @spec changeset(t(), attrs()) :: Ecto.Changeset.t()
  def changeset(turn_log, attrs) do
    turn_log
    |> cast(attrs, [:game_session_id, :turn, :action, :payload_json])
    |> validate_required([:game_session_id, :turn, :action, :payload_json])
    |> validate_number(:turn, greater_than: 0)
  end
end
