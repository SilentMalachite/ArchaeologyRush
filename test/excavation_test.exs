defmodule ArchaeologyRush.ExcavationTest do
  use ExUnit.Case, async: true

  alias ArchaeologyRush.Excavation

  describe "new_session/1" do
    test "builds a session with configured action count" do
      excavation = Excavation.new_session(actions_per_turn: 4)
      state = Excavation.site_state(excavation)

      assert state.actions_per_turn == 4
      assert state.actions_left == 4
    end
  end

  describe "game_status/1" do
    test "returns in_progress while win and loss conditions are unmet" do
      excavation = Excavation.new_session()

      assert Excavation.game_status(excavation) == :in_progress
    end

    test "returns won after enough important artifacts are recovered and report is complete" do
      discovery_fn = fn _cell, _layer, _turn -> %{kind: :stone_tool, quality: :good} end

      excavation =
        Excavation.new_session(target_important_artifacts: 1)
        |> recover_artifact!({1, 1}, discovery_fn)
        |> Excavation.complete_report()

      assert Excavation.game_status(excavation) == :won
    end

    test "returns lost when record misses exceed the session limit" do
      discovery_fn = fn _cell, _layer, _turn -> %{kind: :bone_fragment, quality: :fair} end

      excavation =
        Excavation.new_session(max_record_misses: 1)
        |> dig_without_catalog!({0, 0}, discovery_fn)
        |> Excavation.end_turn()
        |> dig_without_catalog!({0, 1}, discovery_fn)
        |> Excavation.end_turn()

      assert Excavation.game_status(excavation) == {:lost, :too_many_record_misses}
    end

    test "returns lost when turn limit is reached without enough recovered artifacts" do
      excavation =
        Excavation.new_session(max_turns: 1, target_important_artifacts: 1)
        |> Excavation.end_turn()

      assert Excavation.game_status(excavation) == {:lost, :turn_limit_reached}
    end
  end

  describe "dig/catalog/recover/end_turn" do
    test "executes a full happy-path turn through use-case API" do
      discovery_fn = fn _cell, _layer, _turn -> %{kind: :stone_tool, quality: :excellent} end

      {:ok, excavation, artifact} =
        Excavation.new_session()
        |> Excavation.dig({2, 1}, discovery_fn: discovery_fn)

      attrs = %{
        artifact_id: artifact.id,
        coordinate: {2, 1},
        depth: 1,
        layer_id: "upper",
        discovered_turn: 1,
        operator_note: "catalog complete"
      }

      {:ok, excavation, cataloged} = Excavation.catalog(excavation, artifact.id, attrs)
      assert cataloged.status == :cataloged

      {:ok, excavation, recovered} = Excavation.recover(excavation, artifact.id)
      assert recovered.status == :recovered

      finished_turn = Excavation.end_turn(excavation)
      state = Excavation.site_state(finished_turn)

      assert state.turn == 2
      assert state.score == 20
      assert List.last(state.turn_logs).action == :end_turn
    end

    test "returns domain errors as-is" do
      excavation = Excavation.new_session(actions_per_turn: 1)

      {:ok, excavation, nil} = Excavation.dig(excavation, {0, 0})
      assert {:error, :no_actions_left} = Excavation.dig(excavation, {0, 0})

      assert {:error, :artifact_not_found} = Excavation.catalog(excavation, 999, %{})
      assert {:error, :artifact_not_found} = Excavation.recover(excavation, 999)
    end
  end

  defp recover_artifact!(excavation, cell, discovery_fn) do
    {:ok, excavation, artifact} = Excavation.dig(excavation, cell, discovery_fn: discovery_fn)

    attrs = %{
      artifact_id: artifact.id,
      coordinate: cell,
      depth: 1,
      layer_id: "upper",
      discovered_turn: 1,
      operator_note: "catalog complete"
    }

    {:ok, excavation, _artifact} = Excavation.catalog(excavation, artifact.id, attrs)
    {:ok, excavation, _artifact} = Excavation.recover(excavation, artifact.id)
    excavation
  end

  defp dig_without_catalog!(excavation, cell, discovery_fn) do
    {:ok, excavation, _artifact} = Excavation.dig(excavation, cell, discovery_fn: discovery_fn)
    excavation
  end
end
