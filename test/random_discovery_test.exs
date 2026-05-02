defmodule ArchaeologyRush.RandomDiscoveryTest do
  use ExUnit.Case, async: true

  alias ArchaeologyRush.RandomDiscovery

  describe "discovery_fn/0" do
    test "returns a function with arity 3" do
      fun = RandomDiscovery.discovery_fn()
      assert is_function(fun, 3)
    end

    test "returned function produces nil or valid discovery map" do
      fun = RandomDiscovery.discovery_fn()

      results =
        for row <- 0..3, col <- 0..3, layer <- [:upper, :middle, :lower] do
          fun.({row, col}, layer, 1)
        end

      Enum.each(results, fn result ->
        case result do
          nil ->
            :ok

          %{kind: kind, quality: quality} ->
            assert kind in [:pottery_shard, :stone_tool, :bone_fragment, :feature_mark]
            assert quality in [:poor, :fair, :good, :excellent]
        end
      end)
    end

    test "discovery probability increases with deeper layers" do
      fun = RandomDiscovery.discovery_fn()
      sample_size = 1000

      counts =
        for layer <- [:upper, :middle, :lower], into: %{} do
          found =
            Enum.count(1..sample_size, fn _ ->
              fun.({0, 0}, layer, 1) != nil
            end)

          {layer, found / sample_size}
        end

      assert counts[:upper] < counts[:middle]
      assert counts[:middle] < counts[:lower]
    end
  end

  describe "discovery_fn/1" do
    test "uses a cell and layer probability table" do
      fun =
        RandomDiscovery.discovery_fn(
          probability_table: %{{{2, 1}, :middle} => 1.0},
          kind_weights: [stone_tool: 1],
          quality_weights: [excellent: 1]
        )

      assert fun.({2, 1}, :middle, 4) == %{kind: :stone_tool, quality: :excellent}
      assert fun.({2, 1}, :upper, 4) == nil
      assert fun.({0, 0}, :middle, 4) == nil
    end
  end

  describe "default_probability_table/0" do
    test "covers the 4x4 grid for each known layer" do
      table = RandomDiscovery.default_probability_table()

      assert map_size(table) == 48
      assert table[{{0, 0}, :upper}] == 0.10
      assert table[{{3, 3}, :middle}] == 0.25
      assert table[{{1, 2}, :lower}] == 0.40
    end
  end
end
