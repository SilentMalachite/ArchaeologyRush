defmodule ArchaeologyRush.Excavation do
  @moduledoc """
  発掘ユースケース層です。

  `SiteState` の状態遷移をアプリケーションAPIとしてまとめます。
  """

  alias ArchaeologyRush.SiteState

  @type status_reason :: :turn_limit_reached | :too_many_record_misses
  @type game_status :: :in_progress | :won | {:lost, status_reason()}

  @type t :: %__MODULE__{
          site_state: SiteState.t(),
          max_turns: pos_integer(),
          target_important_artifacts: pos_integer(),
          max_record_misses: non_neg_integer(),
          record_misses: non_neg_integer(),
          final_report_complete: boolean()
        }

  defstruct site_state: SiteState.new(),
            max_turns: 10,
            target_important_artifacts: 3,
            max_record_misses: 1,
            record_misses: 0,
            final_report_complete: false

  @spec new_session(keyword()) :: t()
  def new_session(opts \\ []) do
    %__MODULE__{
      site_state: SiteState.new(opts),
      max_turns: Keyword.get(opts, :max_turns, 10),
      target_important_artifacts: Keyword.get(opts, :target_important_artifacts, 3),
      max_record_misses: Keyword.get(opts, :max_record_misses, 1)
    }
  end

  @spec site_state(t()) :: SiteState.t()
  def site_state(%__MODULE__{} = excavation), do: excavation.site_state

  @spec complete_report(t()) :: t()
  def complete_report(%__MODULE__{} = excavation) do
    %{excavation | final_report_complete: true}
  end

  @spec game_status(t()) :: game_status()
  def game_status(%__MODULE__{} = excavation) do
    cond do
      won?(excavation) ->
        :won

      excavation.record_misses > excavation.max_record_misses ->
        {:lost, :too_many_record_misses}

      turn_limit_reached?(excavation) ->
        {:lost, :turn_limit_reached}

      true ->
        :in_progress
    end
  end

  @spec dig(t(), SiteState.cell(), keyword()) ::
          {:ok, t(), nil | SiteState.artifact()}
          | {:error, :no_actions_left | :cell_fully_excavated}
  def dig(%__MODULE__{site_state: state} = excavation, cell, opts \\ []) do
    case SiteState.dig(state, cell, opts) do
      {:ok, next_state, artifact} ->
        {:ok, %{excavation | site_state: next_state}, artifact}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec catalog(t(), pos_integer(), map()) ::
          {:ok, t(), SiteState.artifact()}
          | {:error, :artifact_not_found | {:missing_required_fields, [atom()]}}
  def catalog(%__MODULE__{site_state: state} = excavation, artifact_id, attrs) do
    case SiteState.catalog(state, artifact_id, attrs) do
      {:ok, next_state, artifact} ->
        {:ok, %{excavation | site_state: next_state}, artifact}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec recover(t(), pos_integer()) ::
          {:ok, t(), SiteState.artifact()}
          | {:error, :artifact_not_found | :artifact_not_cataloged}
  def recover(%__MODULE__{site_state: state} = excavation, artifact_id) do
    case SiteState.recover(state, artifact_id) do
      {:ok, next_state, artifact} ->
        {:ok, %{excavation | site_state: next_state}, artifact}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec end_turn(t()) :: t()
  def end_turn(%__MODULE__{site_state: state} = excavation) do
    record_misses =
      state.artifacts
      |> Map.values()
      |> Enum.count(&(&1.status == :discovered))

    %{
      excavation
      | site_state: SiteState.end_turn(state),
        record_misses: excavation.record_misses + record_misses
    }
  end

  @spec won?(t()) :: boolean()
  defp won?(%__MODULE__{} = excavation) do
    excavation.final_report_complete and
      recovered_important_artifact_count(excavation) >= excavation.target_important_artifacts
  end

  @spec turn_limit_reached?(t()) :: boolean()
  defp turn_limit_reached?(%__MODULE__{} = excavation) do
    excavation.site_state.turn > excavation.max_turns and
      recovered_important_artifact_count(excavation) < excavation.target_important_artifacts
  end

  @spec recovered_important_artifact_count(t()) :: non_neg_integer()
  defp recovered_important_artifact_count(%__MODULE__{} = excavation) do
    excavation.site_state.artifacts
    |> Map.values()
    |> Enum.count(fn artifact ->
      artifact.status == :recovered and important_artifact?(artifact)
    end)
  end

  @spec important_artifact?(SiteState.artifact()) :: boolean()
  defp important_artifact?(artifact), do: artifact.kind != :feature_mark
end
