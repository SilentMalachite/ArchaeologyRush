defmodule ArchaeologyRush.Demo do
  @moduledoc """
  Excavation の状態遷移を手元で確認するためのデモ出力を提供します。
  """

  alias ArchaeologyRush.Excavation

  @spec run() :: String.t()
  def run do
    [
      "ArchaeologyRush demo",
      "===================",
      "",
      format_scenario("progression case", progression_case()),
      "",
      format_scenario("winning case", winning_case()),
      "",
      format_scenario("losing case", losing_case())
    ]
    |> Enum.join("\n")
  end

  @spec progression_case() :: [{String.t(), Excavation.t(), pos_integer()}]
  defp progression_case do
    discovery_fn = fn _cell, _layer, _turn ->
      %{kind: :stone_tool, quality: :excellent}
    end

    {:ok, excavation, artifact} =
      Excavation.new_session()
      |> Excavation.dig({2, 1}, discovery_fn: discovery_fn)

    after_dig = excavation

    attrs = %{
      artifact_id: artifact.id,
      coordinate: {2, 1},
      depth: 1,
      layer_id: "upper",
      discovered_turn: 1,
      operator_note: "catalog complete"
    }

    {:ok, excavation, _cataloged} = Excavation.catalog(excavation, artifact.id, attrs)
    after_catalog = excavation

    {:ok, excavation, _recovered} = Excavation.recover(excavation, artifact.id)
    after_recover = excavation

    excavation = Excavation.end_turn(excavation)
    after_end_turn = excavation

    [
      {"after dig", after_dig, artifact.id},
      {"after catalog", after_catalog, artifact.id},
      {"after recover", after_recover, artifact.id},
      {"after end_turn", after_end_turn, artifact.id}
    ]
  end

  @spec winning_case() :: [{String.t(), Excavation.t(), pos_integer()}]
  defp winning_case do
    discovery_fn = fn _cell, _layer, _turn ->
      %{kind: :stone_tool, quality: :good}
    end

    {:ok, excavation, artifact} =
      Excavation.new_session(target_important_artifacts: 1)
      |> Excavation.dig({4, 4}, discovery_fn: discovery_fn)

    attrs = %{
      artifact_id: artifact.id,
      coordinate: {4, 4},
      depth: 1,
      layer_id: "upper",
      discovered_turn: 1,
      operator_note: "winning sample"
    }

    {:ok, excavation, _cataloged} = Excavation.catalog(excavation, artifact.id, attrs)
    {:ok, excavation, _recovered} = Excavation.recover(excavation, artifact.id)
    recovered = excavation

    reported = Excavation.complete_report(excavation)

    [
      {"after recover", recovered, artifact.id},
      {"after complete_report", reported, artifact.id}
    ]
  end

  @spec losing_case() :: [{String.t(), Excavation.t(), pos_integer()}]
  defp losing_case do
    discovery_fn = fn _cell, _layer, _turn ->
      %{kind: :bone_fragment, quality: :fair}
    end

    {:ok, excavation, artifact} =
      Excavation.new_session(max_record_misses: 0)
      |> Excavation.dig({7, 3}, discovery_fn: discovery_fn)

    ended_turn = Excavation.end_turn(excavation)

    [
      {"after dig", excavation, artifact.id},
      {"after end_turn", ended_turn, artifact.id}
    ]
  end

  @spec format_scenario(String.t(), [{String.t(), Excavation.t(), pos_integer()}]) :: String.t()
  defp format_scenario(label, snapshots) do
    [
      "#{label}:",
      Enum.map_join(snapshots, "\n\n", fn {snapshot_label, excavation, artifact_id} ->
        format_snapshot(snapshot_label, excavation, artifact_id)
      end)
    ]
    |> Enum.join("\n")
  end

  @spec format_snapshot(String.t(), Excavation.t(), pos_integer()) :: String.t()
  defp format_snapshot(label, excavation, artifact_id) do
    state = Excavation.site_state(excavation)
    artifact = Map.fetch!(state.artifacts, artifact_id)
    last_log = List.last(state.turn_logs)

    [
      "[#{label}]",
      "game_status=#{inspect(Excavation.game_status(excavation))}",
      "turn=#{state.turn}",
      "actions_left=#{state.actions_left}",
      "score=#{state.score}",
      "artifact_status=#{artifact.status}",
      "artifact_quality=#{artifact.quality}",
      "last_action=#{last_log.action}"
    ]
    |> Enum.join("\n")
  end
end
