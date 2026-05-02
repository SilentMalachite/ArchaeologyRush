defmodule ArchaeologyRush.Persistence do
  @moduledoc """
  発掘セッションを Repo に保存し、ゲーム構造体へ復元するユースケース層です。
  """

  import Ecto.Query

  alias ArchaeologyRush.{Artifact, Excavation, Repo, SavedSession, SiteState, TurnLog}

  @type saved_id :: pos_integer()

  @spec save!(Excavation.t()) :: SavedSession.t()
  def save!(%Excavation{} = excavation) do
    Repo.transaction(fn ->
      saved_session =
        %SavedSession{}
        |> SavedSession.changeset(saved_session_attrs(excavation))
        |> Repo.insert!()

      excavation.site_state.artifacts
      |> Map.values()
      |> Enum.each(fn artifact ->
        %Artifact{}
        |> Artifact.game_changeset(artifact_attrs(saved_session.id, artifact))
        |> Repo.insert!()
      end)

      excavation.site_state.turn_logs
      |> Enum.each(fn log ->
        %TurnLog{}
        |> TurnLog.changeset(turn_log_attrs(saved_session.id, log))
        |> Repo.insert!()
      end)

      saved_session
    end)
    |> case do
      {:ok, saved_session} -> saved_session
      {:error, reason} -> raise "failed to save excavation: #{inspect(reason)}"
    end
  end

  @spec load!(saved_id()) :: Excavation.t()
  def load!(id) do
    saved_session = Repo.get!(SavedSession, id)

    artifacts =
      Artifact
      |> where([a], a.game_session_id == ^id)
      |> order_by([a], asc: a.game_artifact_id)
      |> Repo.all()
      |> Map.new(fn artifact -> {artifact.game_artifact_id, load_artifact(artifact)} end)

    turn_logs =
      TurnLog
      |> where([l], l.game_session_id == ^id)
      |> order_by([l], asc: l.id)
      |> Repo.all()
      |> Enum.map(&load_turn_log/1)

    %Excavation{
      max_turns: saved_session.max_turns,
      target_important_artifacts: saved_session.target_important_artifacts,
      max_record_misses: saved_session.max_record_misses,
      record_misses: saved_session.record_misses,
      final_report_complete: saved_session.final_report_complete,
      site_state: %SiteState{
        turn: saved_session.turn,
        actions_per_turn: saved_session.actions_per_turn,
        actions_left: saved_session.actions_left,
        score: saved_session.score,
        tool_durability: saved_session.tool_durability,
        next_artifact_id: saved_session.next_artifact_id,
        turn_dig_counts: decode_cell_values(saved_session.turn_dig_counts_json),
        cell_progress: decode_cell_values(saved_session.cell_progress_json),
        mixed_layers: decode_mixed_layers(saved_session.mixed_layers_json),
        artifacts: artifacts,
        turn_logs: turn_logs
      }
    }
  end

  defp saved_session_attrs(%Excavation{site_state: state} = excavation) do
    %{
      max_turns: excavation.max_turns,
      target_important_artifacts: excavation.target_important_artifacts,
      max_record_misses: excavation.max_record_misses,
      record_misses: excavation.record_misses,
      final_report_complete: excavation.final_report_complete,
      turn: state.turn,
      actions_per_turn: state.actions_per_turn,
      actions_left: state.actions_left,
      score: state.score,
      tool_durability: state.tool_durability,
      next_artifact_id: state.next_artifact_id,
      turn_dig_counts_json: encode_cell_values(state.turn_dig_counts),
      cell_progress_json: encode_cell_values(state.cell_progress),
      mixed_layers_json: encode_mixed_layers(state.mixed_layers)
    }
  end

  defp artifact_attrs(game_session_id, artifact) do
    {row, col} = artifact.coordinate

    %{
      game_session_id: game_session_id,
      game_artifact_id: artifact.id,
      name: "artifact-#{artifact.id}",
      layer: artifact.layer_id,
      notes: artifact.operator_note,
      kind: Atom.to_string(artifact.kind),
      quality: Atom.to_string(artifact.quality),
      status: Atom.to_string(artifact.status),
      coordinate_row: row,
      coordinate_col: col,
      depth: artifact.depth,
      layer_id: artifact.layer_id,
      discovered_turn: artifact.discovered_turn,
      operator_note: artifact.operator_note
    }
  end

  defp turn_log_attrs(game_session_id, log) do
    %{
      game_session_id: game_session_id,
      turn: log.turn,
      action: Atom.to_string(log.action),
      payload_json:
        log
        |> Map.drop([:turn, :action])
        |> encode_json_value()
    }
  end

  defp load_artifact(artifact) do
    %{
      id: artifact.game_artifact_id,
      kind: String.to_existing_atom(artifact.kind),
      quality: String.to_existing_atom(artifact.quality),
      status: String.to_existing_atom(artifact.status),
      coordinate: {artifact.coordinate_row, artifact.coordinate_col},
      depth: artifact.depth,
      layer_id: artifact.layer_id,
      discovered_turn: artifact.discovered_turn,
      operator_note: artifact.operator_note
    }
  end

  defp load_turn_log(turn_log) do
    turn_log.payload_json
    |> decode_json_value()
    |> Map.merge(%{
      turn: turn_log.turn,
      action: String.to_existing_atom(turn_log.action)
    })
  end

  defp encode_cell_values(values) do
    values
    |> Enum.map(fn {{row, col}, value} -> %{row: row, col: col, value: value} end)
    |> Jason.encode!()
  end

  defp decode_cell_values(json) do
    json
    |> Jason.decode!()
    |> Map.new(fn %{"row" => row, "col" => col, "value" => value} -> {{row, col}, value} end)
  end

  defp encode_mixed_layers(mixed_layers) do
    mixed_layers
    |> Enum.map(fn {{row, col}, layer} -> %{row: row, col: col, layer: Atom.to_string(layer)} end)
    |> Jason.encode!()
  end

  defp decode_mixed_layers(json) do
    json
    |> Jason.decode!()
    |> Enum.map(fn %{"row" => row, "col" => col, "layer" => layer} ->
      {{row, col}, String.to_existing_atom(layer)}
    end)
    |> MapSet.new()
  end

  defp encode_json_value(value) do
    value
    |> to_json_value()
    |> Jason.encode!()
  end

  defp decode_json_value(json) do
    json
    |> Jason.decode!()
    |> from_json_value()
  end

  defp to_json_value({row, col}), do: %{"__type__" => "cell", "row" => row, "col" => col}
  defp to_json_value(value) when is_atom(value), do: Atom.to_string(value)
  defp to_json_value(value) when is_list(value), do: Enum.map(value, &to_json_value/1)

  defp to_json_value(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {Atom.to_string(key), to_json_value(nested_value)}
    end)
  end

  defp to_json_value(value), do: value

  defp from_json_value(%{"__type__" => "cell", "row" => row, "col" => col}), do: {row, col}

  defp from_json_value(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {String.to_existing_atom(key), from_json_value(nested_value)}
    end)
  end

  defp from_json_value(value) when is_list(value), do: Enum.map(value, &from_json_value/1)
  defp from_json_value("upper"), do: :upper
  defp from_json_value("middle"), do: :middle
  defp from_json_value("lower"), do: :lower
  defp from_json_value("ok"), do: :ok
  defp from_json_value(value), do: value
end
