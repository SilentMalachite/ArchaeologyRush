defmodule ArchaeologyRush.SiteState do
  @moduledoc """
  発掘セッションのコア状態遷移を扱うモジュールです。

  このモジュールは UI/DB に依存しない純粋な状態更新だけを提供します。
  """

  @type cell :: {integer(), integer()}
  @type layer :: :upper | :middle | :lower
  @type artifact_kind :: :pottery_shard | :stone_tool | :bone_fragment | :feature_mark
  @type artifact_quality :: :poor | :fair | :good | :excellent

  @required_catalog_fields ~w(artifact_id coordinate depth layer_id discovered_turn operator_note)a
  @layer_order [:upper, :middle, :lower]

  @type artifact_status :: :discovered | :on_hold | :cataloged | :recovered

  @type artifact :: %{
          id: pos_integer(),
          kind: artifact_kind(),
          quality: artifact_quality(),
          status: artifact_status(),
          coordinate: cell() | nil,
          depth: non_neg_integer() | nil,
          layer_id: String.t() | nil,
          discovered_turn: pos_integer(),
          operator_note: String.t() | nil
        }

  @type t :: %__MODULE__{
          turn: pos_integer(),
          actions_per_turn: pos_integer(),
          actions_left: non_neg_integer(),
          score: integer(),
          tool_durability: integer(),
          next_artifact_id: pos_integer(),
          turn_dig_counts: %{optional(cell()) => non_neg_integer()},
          cell_progress: %{optional(cell()) => non_neg_integer()},
          mixed_layers: MapSet.t({cell(), layer()}),
          artifacts: %{optional(pos_integer()) => artifact()},
          turn_logs: [map()]
        }

  defstruct turn: 1,
            actions_per_turn: 3,
            actions_left: 3,
            score: 0,
            tool_durability: 30,
            next_artifact_id: 1,
            turn_dig_counts: %{},
            cell_progress: %{},
            mixed_layers: MapSet.new(),
            artifacts: %{},
            turn_logs: []

  @type discovery_result :: nil | %{kind: artifact_kind(), quality: artifact_quality()}
  @type discovery_fn :: (cell(), layer(), pos_integer() -> discovery_result())

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    actions_per_turn = Keyword.get(opts, :actions_per_turn, 3)
    tool_durability = Keyword.get(opts, :tool_durability, 30)

    %__MODULE__{
      actions_per_turn: actions_per_turn,
      actions_left: actions_per_turn,
      tool_durability: tool_durability
    }
  end

  @spec dig(t(), cell(), keyword()) ::
          {:ok, t(), nil | artifact()} | {:error, :no_actions_left | :cell_fully_excavated}
  def dig(state, cell, opts \\ [])

  def dig(%__MODULE__{actions_left: 0}, _cell, _opts), do: {:error, :no_actions_left}

  def dig(%__MODULE__{} = state, cell, opts) do
    progress = Map.get(state.cell_progress, cell, 0)

    if progress >= length(@layer_order) do
      {:error, :cell_fully_excavated}
    else
      layer = Enum.at(@layer_order, progress)
      dig_count = Map.get(state.turn_dig_counts, cell, 0) + 1
      penalty? = dig_count >= 3
      discovery_fn = Keyword.get(opts, :discovery_fn, fn _, _, _ -> nil end)
      discovery = discovery_fn.(cell, layer, state.turn)

      {next_state, discovered_artifact} =
        state
        |> consume_action()
        |> put_dig_result(cell, progress + 1, dig_count, layer, penalty?)
        |> maybe_add_discovered_artifact(discovery, cell, progress, layer)

      next_state =
        append_log(next_state, %{
          action: :dig,
          cell: cell,
          layer: layer,
          penalty_applied: penalty?
        })

      {:ok, next_state, discovered_artifact}
    end
  end

  @spec catalog(t(), pos_integer(), map()) ::
          {:ok, t(), artifact()}
          | {:error, :artifact_not_found | {:missing_required_fields, [atom()]}}
  def catalog(%__MODULE__{} = state, artifact_id, attrs) do
    case Map.fetch(state.artifacts, artifact_id) do
      :error ->
        {:error, :artifact_not_found}

      {:ok, artifact} ->
        merged = Map.merge(artifact, attrs)
        missing = Enum.filter(@required_catalog_fields, &blank?(Map.get(merged, &1)))

        if missing == [] do
          cataloged = %{merged | status: :cataloged}

          next_state =
            state
            |> put_in([Access.key(:artifacts), artifact_id], cataloged)
            |> append_log(%{action: :catalog, artifact_id: artifact_id, result: :ok})

          {:ok, next_state, cataloged}
        else
          {:error, {:missing_required_fields, missing}}
        end
    end
  end

  @spec recover(t(), pos_integer()) ::
          {:ok, t(), artifact()} | {:error, :artifact_not_found | :artifact_not_cataloged}
  def recover(%__MODULE__{} = state, artifact_id) do
    case Map.fetch(state.artifacts, artifact_id) do
      :error ->
        {:error, :artifact_not_found}

      {:ok, %{status: :cataloged} = artifact} ->
        recovered = %{artifact | status: :recovered}
        gain = round(10 * quality_multiplier(artifact.quality))

        next_state =
          state
          |> put_in([Access.key(:artifacts), artifact_id], recovered)
          |> Map.update!(:score, &(&1 + gain))
          |> append_log(%{action: :recover, artifact_id: artifact_id, score_gain: gain})

        {:ok, next_state, recovered}

      {:ok, _artifact} ->
        {:error, :artifact_not_cataloged}
    end
  end

  @spec end_turn(t()) :: t()
  def end_turn(%__MODULE__{} = state) do
    artifacts =
      Enum.into(state.artifacts, %{}, fn {id, artifact} ->
        next =
          if artifact.status == :discovered do
            %{artifact | status: :on_hold}
          else
            artifact
          end

        {id, next}
      end)

    state
    |> Map.put(:artifacts, artifacts)
    |> Map.put(:turn, state.turn + 1)
    |> Map.put(:actions_left, state.actions_per_turn)
    |> Map.put(:turn_dig_counts, %{})
    |> append_log(%{action: :end_turn, next_turn: state.turn + 1})
  end

  @spec consume_action(t()) :: t()
  defp consume_action(state) do
    state
    |> Map.update!(:actions_left, &max(&1 - 1, 0))
    |> Map.update!(:tool_durability, &max(&1 - 1, 0))
  end

  @spec put_dig_result(t(), cell(), non_neg_integer(), pos_integer(), layer(), boolean()) :: t()
  defp put_dig_result(state, cell, progress, dig_count, layer, penalty?) do
    mixed_layers =
      if penalty? do
        MapSet.put(state.mixed_layers, {cell, layer})
      else
        state.mixed_layers
      end

    state
    |> put_in([Access.key(:cell_progress), cell], progress)
    |> put_in([Access.key(:turn_dig_counts), cell], dig_count)
    |> Map.put(:mixed_layers, mixed_layers)
    |> maybe_apply_penalty(penalty?)
  end

  @spec maybe_apply_penalty(t(), boolean()) :: t()
  defp maybe_apply_penalty(state, true), do: Map.update!(state, :score, &(&1 - 5))
  defp maybe_apply_penalty(state, false), do: state

  @spec maybe_add_discovered_artifact(t(), discovery_result(), cell(), non_neg_integer(), layer()) ::
          {t(), nil | artifact()}
  defp maybe_add_discovered_artifact(state, nil, _cell, _progress, _layer), do: {state, nil}

  defp maybe_add_discovered_artifact(state, discovery, cell, progress, layer) do
    artifact = %{
      id: state.next_artifact_id,
      kind: discovery.kind,
      quality: discovery.quality,
      status: :discovered,
      coordinate: cell,
      depth: progress + 1,
      layer_id: Atom.to_string(layer),
      discovered_turn: state.turn,
      operator_note: nil
    }

    next_state =
      state
      |> put_in([Access.key(:artifacts), artifact.id], artifact)
      |> Map.update!(:next_artifact_id, &(&1 + 1))

    {next_state, artifact}
  end

  @spec append_log(t(), map()) :: t()
  defp append_log(state, entry) do
    log = Map.put(entry, :turn, state.turn)
    Map.update!(state, :turn_logs, &(&1 ++ [log]))
  end

  @spec quality_multiplier(artifact_quality()) :: float()
  defp quality_multiplier(:poor), do: 0.5
  defp quality_multiplier(:fair), do: 1.0
  defp quality_multiplier(:good), do: 1.5
  defp quality_multiplier(:excellent), do: 2.0

  @spec blank?(term()) :: boolean()
  defp blank?(value) when value in [nil, ""], do: true
  defp blank?(_value), do: false
end
