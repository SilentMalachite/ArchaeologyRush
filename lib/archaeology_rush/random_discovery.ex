defmodule ArchaeologyRush.RandomDiscovery do
  @moduledoc """
  ランダムなアーティファクト発見ロジック。

  SiteState.discovery_fn 型に準拠するコールバックを提供します。
  発見確率はセルと層の組み合わせで定義したテーブルから参照します。
  """

  alias ArchaeologyRush.SiteState

  @type probability :: float()
  @type probability_table :: %{{SiteState.cell(), SiteState.layer()} => probability()}
  @type weighted_options :: [{atom(), pos_integer()}]

  @kind_weights [
    {:pottery_shard, 1},
    {:stone_tool, 1},
    {:bone_fragment, 1},
    {:feature_mark, 1}
  ]

  @quality_weights [
    {:poor, 40},
    {:fair, 35},
    {:good, 20},
    {:excellent, 5}
  ]

  @layer_discovery_rates %{
    upper: 0.10,
    middle: 0.25,
    lower: 0.40
  }

  @spec discovery_fn() :: SiteState.discovery_fn()
  def discovery_fn do
    discovery_fn([])
  end

  @spec discovery_fn(keyword()) :: SiteState.discovery_fn()
  def discovery_fn(opts) do
    probability_table = Keyword.get(opts, :probability_table, default_probability_table())
    kind_weights = Keyword.get(opts, :kind_weights, @kind_weights)
    quality_weights = Keyword.get(opts, :quality_weights, @quality_weights)

    fn cell, layer, turn ->
      maybe_discover(cell, layer, turn, probability_table, kind_weights, quality_weights)
    end
  end

  @spec default_probability_table() :: probability_table()
  def default_probability_table do
    for row <- 0..3,
        col <- 0..3,
        {layer, probability} <- @layer_discovery_rates,
        into: %{} do
      {{{row, col}, layer}, probability}
    end
  end

  @spec maybe_discover(
          SiteState.cell(),
          SiteState.layer(),
          pos_integer(),
          probability_table(),
          weighted_options(),
          weighted_options()
        ) ::
          SiteState.discovery_result()
  defp maybe_discover(cell, layer, _turn, probability_table, kind_weights, quality_weights) do
    case Map.fetch(probability_table, {cell, layer}) do
      {:ok, probability} ->
        discover_with_probability(probability, kind_weights, quality_weights)

      :error ->
        nil
    end
  end

  @spec discover_with_probability(probability(), weighted_options(), weighted_options()) ::
          SiteState.discovery_result()
  defp discover_with_probability(probability, kind_weights, quality_weights) do
    if :rand.uniform() <= probability do
      %{
        kind: weighted_random(kind_weights),
        quality: weighted_random(quality_weights)
      }
    else
      nil
    end
  end

  @spec weighted_random(weighted_options()) :: atom()
  defp weighted_random(weights) do
    total = Enum.reduce(weights, 0, fn {_val, w}, acc -> acc + w end)
    roll = :rand.uniform(total)

    Enum.reduce_while(weights, 0, fn {val, w}, acc ->
      acc = acc + w
      if roll <= acc, do: {:halt, val}, else: {:cont, acc}
    end)
  end
end
