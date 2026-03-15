defmodule ArchaeologyRush.SiteStateTest do
  use ExUnit.Case, async: true

  alias ArchaeologyRush.SiteState

  describe "dig/3" do
    test "consumes an action and advances layer progress" do
      state = SiteState.new()

      {:ok, state, nil} = SiteState.dig(state, {1, 1})
      assert state.actions_left == 2
      assert state.tool_durability == 29
      assert state.cell_progress[{1, 1}] == 1
    end

    test "applies penalty on third dig in same turn for same cell" do
      state = SiteState.new()

      {:ok, state, nil} = SiteState.dig(state, {2, 2})
      {:ok, state, nil} = SiteState.dig(state, {2, 2})
      {:ok, state, nil} = SiteState.dig(state, {2, 2})

      assert state.score == -5
      assert MapSet.member?(state.mixed_layers, {{2, 2}, :lower})
    end

    test "creates discovered artifact when discovery function returns a result" do
      discovery_fn = fn _cell, _layer, _turn -> %{kind: :pottery_shard, quality: :good} end

      {:ok, state, artifact} =
        SiteState.new() |> SiteState.dig({3, 4}, discovery_fn: discovery_fn)

      assert artifact.id == 1
      assert artifact.status == :discovered
      assert state.artifacts[artifact.id].kind == :pottery_shard
    end
  end

  describe "catalog/3 and recover/2" do
    test "requires mandatory catalog fields before recover" do
      discovery_fn = fn _cell, _layer, _turn -> %{kind: :stone_tool, quality: :excellent} end

      {:ok, state, artifact} =
        SiteState.new() |> SiteState.dig({0, 0}, discovery_fn: discovery_fn)

      assert {:error, {:missing_required_fields, missing}} =
               SiteState.catalog(state, artifact.id, %{})

      assert :artifact_id in missing

      attrs = %{
        artifact_id: artifact.id,
        coordinate: {0, 0},
        depth: 1,
        layer_id: "upper",
        discovered_turn: 1,
        operator_note: "well preserved"
      }

      {:ok, state, cataloged} = SiteState.catalog(state, artifact.id, attrs)
      assert cataloged.status == :cataloged

      {:ok, state, recovered} = SiteState.recover(state, artifact.id)
      assert recovered.status == :recovered
      assert state.score == 20
    end
  end

  describe "end_turn/1" do
    test "moves undisclosed artifacts to on_hold and resets actions" do
      discovery_fn = fn _cell, _layer, _turn -> %{kind: :bone_fragment, quality: :fair} end

      {:ok, state, artifact} =
        SiteState.new() |> SiteState.dig({9, 9}, discovery_fn: discovery_fn)

      next_state = SiteState.end_turn(state)

      assert next_state.turn == 2
      assert next_state.actions_left == 3
      assert next_state.turn_dig_counts == %{}
      assert next_state.artifacts[artifact.id].status == :on_hold
    end
  end
end
