defmodule ArchaeologyRush.Demo do
  @moduledoc """
  Excavation の状態遷移を手元で確認するためのデモ出力を提供します。
  """

  alias ArchaeologyRush.Excavation

  @type snapshot :: %{
          label: String.t(),
          game_status: Excavation.game_status(),
          turn: pos_integer(),
          actions_left: non_neg_integer(),
          score: integer(),
          artifact_status: atom(),
          artifact_quality: atom(),
          last_action: atom()
        }

  @type scenario :: %{
          id: atom(),
          title: String.t(),
          subtitle: String.t(),
          snapshots: [snapshot()]
        }

  @spec run() :: String.t()
  def run do
    scenarios()
    |> Enum.map_join("\n\n", &format_scenario/1)
    |> then(&Enum.join(["ArchaeologyRush demo", "===================", "", &1], "\n"))
  end

  @spec scenarios() :: [scenario()]
  def scenarios do
    [
      %{
        id: :progression,
        title: "progression case",
        subtitle: "進行中の基本フロー",
        snapshots: progression_case()
      },
      %{
        id: :winning,
        title: "winning case",
        subtitle: "重要遺物の回収後に完了報告して勝利",
        snapshots: winning_case()
      },
      %{
        id: :losing,
        title: "losing case",
        subtitle: "記録漏れ上限超過で敗北",
        snapshots: losing_case()
      }
    ]
  end

  @spec progression_case() :: [snapshot()]
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
      build_snapshot("after dig", after_dig, artifact.id),
      build_snapshot("after catalog", after_catalog, artifact.id),
      build_snapshot("after recover", after_recover, artifact.id),
      build_snapshot("after end_turn", after_end_turn, artifact.id)
    ]
  end

  @spec winning_case() :: [snapshot()]
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
      build_snapshot("after recover", recovered, artifact.id),
      build_snapshot("after complete_report", reported, artifact.id)
    ]
  end

  @spec losing_case() :: [snapshot()]
  defp losing_case do
    discovery_fn = fn _cell, _layer, _turn ->
      %{kind: :bone_fragment, quality: :fair}
    end

    {:ok, excavation, artifact} =
      Excavation.new_session(max_record_misses: 0)
      |> Excavation.dig({7, 3}, discovery_fn: discovery_fn)

    ended_turn = Excavation.end_turn(excavation)

    [
      build_snapshot("after dig", excavation, artifact.id),
      build_snapshot("after end_turn", ended_turn, artifact.id)
    ]
  end

  @spec format_scenario(scenario()) :: String.t()
  defp format_scenario(scenario) do
    [
      "#{scenario.title}:",
      Enum.map_join(scenario.snapshots, "\n\n", &format_snapshot/1)
    ]
    |> Enum.join("\n")
  end

  @spec build_snapshot(String.t(), Excavation.t(), pos_integer()) :: snapshot()
  defp build_snapshot(label, excavation, artifact_id) do
    state = Excavation.site_state(excavation)
    artifact = Map.fetch!(state.artifacts, artifact_id)
    last_log = List.last(state.turn_logs)

    %{
      label: label,
      game_status: Excavation.game_status(excavation),
      turn: state.turn,
      actions_left: state.actions_left,
      score: state.score,
      artifact_status: artifact.status,
      artifact_quality: artifact.quality,
      last_action: last_log.action
    }
  end

  @spec format_snapshot(snapshot()) :: String.t()
  defp format_snapshot(snapshot) do
    [
      "[#{snapshot.label}]",
      "game_status=#{inspect(snapshot.game_status)}",
      "turn=#{snapshot.turn}",
      "actions_left=#{snapshot.actions_left}",
      "score=#{snapshot.score}",
      "artifact_status=#{snapshot.artifact_status}",
      "artifact_quality=#{snapshot.artifact_quality}",
      "last_action=#{snapshot.last_action}"
    ]
    |> Enum.join("\n")
  end
end
