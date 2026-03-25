defmodule ArchaeologyRush.GameSessionTest do
  use ExUnit.Case, async: true

  alias ArchaeologyRush.Excavation
  alias ArchaeologyRush.GameSession

  # テスト用の確定的discovery_fn（必ず発見する）
  defp always_discover_fn do
    fn _cell, _layer, _turn ->
      %{kind: :pottery_shard, quality: :good}
    end
  end

  describe "start_link/1 and get_state/1" do
    test "starts a new game session with default state" do
      {:ok, pid} = GameSession.start_link([])
      state = GameSession.get_state(pid)
      assert %Excavation{} = state
      assert state.site_state.turn == 1
      assert state.site_state.actions_left == 3
    end

    test "accepts custom options" do
      {:ok, pid} = GameSession.start_link(max_turns: 5, discovery_fn: always_discover_fn())
      state = GameSession.get_state(pid)
      assert state.max_turns == 5
    end
  end

  describe "dig/2" do
    test "digs a cell and returns updated state with possible artifact" do
      {:ok, pid} = GameSession.start_link(discovery_fn: always_discover_fn())
      assert {:ok, state, artifact} = GameSession.dig(pid, {0, 0})
      assert state.site_state.actions_left == 2
      assert state.site_state.cell_progress[{0, 0}] == 1
      assert artifact != nil
      assert artifact.kind == :pottery_shard
    end

    test "returns error when no actions left" do
      {:ok, pid} = GameSession.start_link(actions_per_turn: 1, discovery_fn: always_discover_fn())
      {:ok, _state, _artifact} = GameSession.dig(pid, {0, 0})
      assert {:error, :no_actions_left} = GameSession.dig(pid, {1, 1})
    end
  end

  describe "catalog/3" do
    test "catalogs a discovered artifact with operator_note" do
      {:ok, pid} = GameSession.start_link(discovery_fn: always_discover_fn())
      {:ok, _state, artifact} = GameSession.dig(pid, {0, 0})

      attrs = %{operator_note: "テスト記録", artifact_id: artifact.id}
      assert {:ok, state, cataloged} = GameSession.catalog(pid, artifact.id, attrs)
      assert cataloged.status == :cataloged
      assert cataloged.operator_note == "テスト記録"
      assert state.site_state.artifacts[artifact.id].status == :cataloged
    end
  end

  describe "recover/2" do
    test "recovers a cataloged artifact and adds score" do
      {:ok, pid} = GameSession.start_link(discovery_fn: always_discover_fn())
      {:ok, _state, artifact} = GameSession.dig(pid, {0, 0})

      {:ok, _state, _cataloged} =
        GameSession.catalog(pid, artifact.id, %{operator_note: "memo", artifact_id: artifact.id})

      assert {:ok, state, recovered} = GameSession.recover(pid, artifact.id)
      assert recovered.status == :recovered
      assert state.site_state.score > 0
    end
  end

  describe "end_turn/1" do
    test "advances to the next turn" do
      {:ok, pid} = GameSession.start_link([])
      state = GameSession.end_turn(pid)
      assert state.site_state.turn == 2
      assert state.site_state.actions_left == 3
    end
  end

  describe "complete_report/1" do
    test "marks the report as complete" do
      {:ok, pid} = GameSession.start_link([])
      state = GameSession.complete_report(pid)
      assert state.final_report_complete == true
    end
  end

  describe "game lifecycle" do
    test "full game: dig -> catalog -> recover -> complete_report -> won" do
      {:ok, pid} =
        GameSession.start_link(
          target_important_artifacts: 1,
          discovery_fn: always_discover_fn()
        )

      {:ok, _state, artifact} = GameSession.dig(pid, {0, 0})

      {:ok, _state, _cataloged} =
        GameSession.catalog(pid, artifact.id, %{operator_note: "note", artifact_id: artifact.id})

      {:ok, _state, _recovered} = GameSession.recover(pid, artifact.id)

      state = GameSession.complete_report(pid)
      assert Excavation.game_status(state) == :won
    end
  end
end
