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
end
