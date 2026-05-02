defmodule ArchaeologyRush.PersistenceTest do
  use ArchaeologyRush.RepoCase, async: false

  alias ArchaeologyRush.{Excavation, Persistence}

  setup do
    reset_table!("game_sessions", [
      integer_primary_key(),
      "max_turns INTEGER NOT NULL",
      "target_important_artifacts INTEGER NOT NULL",
      "max_record_misses INTEGER NOT NULL",
      "record_misses INTEGER NOT NULL",
      "final_report_complete BOOLEAN NOT NULL",
      "turn INTEGER NOT NULL",
      "actions_per_turn INTEGER NOT NULL",
      "actions_left INTEGER NOT NULL",
      "score INTEGER NOT NULL",
      "tool_durability INTEGER NOT NULL",
      "next_artifact_id INTEGER NOT NULL",
      required_text("turn_dig_counts_json"),
      required_text("cell_progress_json"),
      required_text("mixed_layers_json"),
      required_text("inserted_at"),
      required_text("updated_at")
    ])

    reset_table!("artifacts", [
      integer_primary_key(),
      "game_session_id INTEGER",
      "game_artifact_id INTEGER",
      required_text("name"),
      required_text("layer"),
      optional_text("notes"),
      optional_text("kind"),
      optional_text("quality"),
      optional_text("status"),
      "coordinate_row INTEGER",
      "coordinate_col INTEGER",
      "depth INTEGER",
      optional_text("layer_id"),
      "discovered_turn INTEGER",
      optional_text("context_type"),
      optional_text("operator_note"),
      required_text("inserted_at"),
      required_text("updated_at")
    ])

    reset_table!("turn_logs", [
      integer_primary_key(),
      "game_session_id INTEGER NOT NULL",
      "turn INTEGER NOT NULL",
      required_text("action"),
      required_text("payload_json"),
      required_text("inserted_at"),
      required_text("updated_at")
    ])

    :ok
  end

  describe "save!/1 and load!/1" do
    test "round-trips excavation state, artifacts, and turn logs" do
      excavation =
        [max_turns: 7, target_important_artifacts: 1, max_record_misses: 2]
        |> Excavation.new_session()
        |> dig_with_discovery({1, 2})
        |> catalog_artifact(1, "documented in grid square")
        |> recover_artifact(1)
        |> Excavation.end_turn()
        |> Excavation.complete_report()

      saved = Persistence.save!(excavation)
      loaded = Persistence.load!(saved.id)

      assert loaded.max_turns == 7
      assert loaded.target_important_artifacts == 1
      assert loaded.max_record_misses == 2
      assert loaded.record_misses == 0
      assert loaded.final_report_complete

      assert loaded.site_state.turn == 2
      assert loaded.site_state.actions_left == 3
      assert loaded.site_state.score == 15
      assert loaded.site_state.tool_durability == 29
      assert loaded.site_state.cell_progress == %{{1, 2} => 1}
      assert loaded.site_state.turn_dig_counts == %{}
      assert loaded.site_state.mixed_layers == MapSet.new()

      assert loaded.site_state.artifacts == %{
               1 => %{
                 id: 1,
                 kind: :pottery_shard,
                 quality: :good,
                 status: :recovered,
                 coordinate: {1, 2},
                 depth: 1,
                 layer_id: "upper",
                 discovered_turn: 1,
                 context_type: "feature_inside",
                 operator_note: "documented in grid square"
               }
             }

      assert Enum.map(loaded.site_state.turn_logs, & &1.action) == [
               :dig,
               :catalog,
               :recover,
               :end_turn
             ]
    end
  end

  defp dig_with_discovery(excavation, cell) do
    discovery_fn = fn _cell, _layer, _turn -> %{kind: :pottery_shard, quality: :good} end
    {:ok, excavation, _artifact} = Excavation.dig(excavation, cell, discovery_fn: discovery_fn)
    excavation
  end

  defp catalog_artifact(excavation, artifact_id, note) do
    {:ok, excavation, _artifact} =
      Excavation.catalog(excavation, artifact_id, %{
        artifact_id: artifact_id,
        context_type: "feature_inside",
        operator_note: note
      })

    excavation
  end

  defp recover_artifact(excavation, artifact_id) do
    {:ok, excavation, _artifact} = Excavation.recover(excavation, artifact_id)
    excavation
  end
end
