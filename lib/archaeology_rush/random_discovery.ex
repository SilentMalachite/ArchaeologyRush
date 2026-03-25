defmodule ArchaeologyRush.RandomDiscovery do
  @moduledoc """
  ランダムなアーティファクト発見ロジック。

  SiteState.discovery_fn 型に準拠するコールバックを提供します。
  プロトタイプ用の仮実装であり、後からドメイン仕様に差し替え可能です。
  """

  alias ArchaeologyRush.SiteState

  @kind_options [:pottery_shard, :stone_tool, :bone_fragment, :feature_mark]

  @quality_weights [
    {:poor, 40},
    {:fair, 35},
    {:good, 20},
    {:excellent, 5}
  ]

  @layer_discovery_rates %{
    upper: 0.20,
    middle: 0.40,
    lower: 0.60
  }

  @spec discovery_fn() :: SiteState.discovery_fn()
  def discovery_fn do
    fn cell, layer, turn -> maybe_discover(cell, layer, turn) end
  end

  @spec maybe_discover(SiteState.cell(), SiteState.layer(), pos_integer()) ::
          SiteState.discovery_result()
  defp maybe_discover(_cell, layer, _turn) do
    rate = Map.fetch!(@layer_discovery_rates, layer)

    if :rand.uniform() < rate do
      %{
        kind: Enum.random(@kind_options),
        quality: weighted_random(@quality_weights)
      }
    else
      nil
    end
  end

  @spec weighted_random([{atom(), pos_integer()}]) :: atom()
  defp weighted_random(weights) do
    total = Enum.reduce(weights, 0, fn {_val, w}, acc -> acc + w end)
    roll = :rand.uniform(total)

    Enum.reduce_while(weights, 0, fn {val, w}, acc ->
      acc = acc + w
      if roll <= acc, do: {:halt, val}, else: {:cont, acc}
    end)
  end
end
