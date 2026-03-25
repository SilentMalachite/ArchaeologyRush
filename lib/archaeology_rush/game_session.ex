defmodule ArchaeologyRush.GameSession do
  @moduledoc """
  ゲームセッションを管理する GenServer。

  LiveView の mount 時に起動し、Excavation 構造体を保持します。
  LiveView プロセスにリンクするため、LiveView が閉じると自動終了します。
  """

  use GenServer

  alias ArchaeologyRush.Excavation
  alias ArchaeologyRush.RandomDiscovery
  alias ArchaeologyRush.SiteState

  @type option ::
          {:max_turns, pos_integer()}
          | {:target_important_artifacts, pos_integer()}
          | {:max_record_misses, non_neg_integer()}
          | {:actions_per_turn, pos_integer()}
          | {:tool_durability, pos_integer()}
          | {:discovery_fn, SiteState.discovery_fn()}

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec dig(pid(), SiteState.cell()) ::
          {:ok, Excavation.t(), SiteState.artifact() | nil}
          | {:error, :no_actions_left | :cell_fully_excavated}
  def dig(pid, cell) do
    GenServer.call(pid, {:dig, cell})
  end

  @spec catalog(pid(), pos_integer(), map()) ::
          {:ok, Excavation.t(), SiteState.artifact()}
          | {:error, :artifact_not_found | {:missing_required_fields, [atom()]}}
  def catalog(pid, artifact_id, attrs) do
    GenServer.call(pid, {:catalog, artifact_id, attrs})
  end

  @spec recover(pid(), pos_integer()) ::
          {:ok, Excavation.t(), SiteState.artifact()}
          | {:error, :artifact_not_found | :artifact_not_cataloged}
  def recover(pid, artifact_id) do
    GenServer.call(pid, {:recover, artifact_id})
  end

  @spec end_turn(pid()) :: Excavation.t()
  def end_turn(pid) do
    GenServer.call(pid, :end_turn)
  end

  @spec complete_report(pid()) :: Excavation.t()
  def complete_report(pid) do
    GenServer.call(pid, :complete_report)
  end

  @spec get_state(pid()) :: Excavation.t()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  # --- Server callbacks ---

  @impl true
  def init(opts) do
    discovery_fn = Keyword.get(opts, :discovery_fn, RandomDiscovery.discovery_fn())
    excavation = Excavation.new_session(opts)
    {:ok, %{excavation: excavation, discovery_fn: discovery_fn}}
  end

  @impl true
  def handle_call({:dig, cell}, _from, state) do
    case Excavation.dig(state.excavation, cell, discovery_fn: state.discovery_fn) do
      {:ok, excavation, artifact} ->
        {:reply, {:ok, excavation, artifact}, %{state | excavation: excavation}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:catalog, artifact_id, attrs}, _from, state) do
    case Excavation.catalog(state.excavation, artifact_id, attrs) do
      {:ok, excavation, artifact} ->
        {:reply, {:ok, excavation, artifact}, %{state | excavation: excavation}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:recover, artifact_id}, _from, state) do
    case Excavation.recover(state.excavation, artifact_id) do
      {:ok, excavation, artifact} ->
        {:reply, {:ok, excavation, artifact}, %{state | excavation: excavation}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:end_turn, _from, state) do
    excavation = Excavation.end_turn(state.excavation)
    {:reply, excavation, %{state | excavation: excavation}}
  end

  @impl true
  def handle_call(:complete_report, _from, state) do
    excavation = Excavation.complete_report(state.excavation)
    {:reply, excavation, %{state | excavation: excavation}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.excavation, state}
  end
end
