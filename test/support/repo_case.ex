defmodule ArchaeologyRush.RepoCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      alias ArchaeologyRush.Repo
      import ArchaeologyRush.RepoCase
    end
  end

  setup do
    start_supervised!(ArchaeologyRush.Repo)
    :ok
  end

  @spec integer_primary_key(String.t()) :: String.t()
  def integer_primary_key(name \\ "id") when is_binary(name) do
    "#{name} INTEGER PRIMARY KEY"
  end

  @spec required_text(String.t()) :: String.t()
  def required_text(name) when is_binary(name) do
    "#{name} TEXT NOT NULL"
  end

  @spec optional_text(String.t()) :: String.t()
  def optional_text(name) when is_binary(name) do
    "#{name} TEXT"
  end

  @spec reset_table!(String.t(), [String.t()]) :: :ok
  def reset_table!(table_name, columns) when is_binary(table_name) and is_list(columns) do
    ArchaeologyRush.Repo.query!("DROP TABLE IF EXISTS #{table_name}")

    columns_sql = Enum.join(columns, ", ")
    ArchaeologyRush.Repo.query!("CREATE TABLE #{table_name} (#{columns_sql})")

    :ok
  end

  @spec insert_row!(String.t(), [String.t()], [term()]) :: :ok
  def insert_row!(table_name, columns, values)
      when is_binary(table_name) and is_list(columns) and is_list(values) do
    placeholders =
      1..length(values)
      |> Enum.map_join(", ", &"?#{&1}")

    columns_sql = Enum.join(columns, ", ")
    ArchaeologyRush.Repo.query!(
      "INSERT INTO #{table_name} (#{columns_sql}) VALUES (#{placeholders})",
      values
    )

    :ok
  end

  @spec insert_rows!(String.t(), [String.t()], [[term()]]) :: :ok
  def insert_rows!(table_name, columns, rows)
      when is_binary(table_name) and is_list(columns) and is_list(rows) do
    Enum.each(rows, fn values ->
      insert_row!(table_name, columns, values)
    end)

    :ok
  end

  @spec clear_table!(String.t()) :: :ok
  def clear_table!(table_name) when is_binary(table_name) do
    ArchaeologyRush.Repo.query!("DELETE FROM #{table_name}")
    :ok
  end

  @spec fetch_all!(String.t()) :: [[term()]]
  def fetch_all!(query) when is_binary(query) do
    query
    |> ArchaeologyRush.Repo.query!()
    |> Map.fetch!(:rows)
  end

  @spec fetch_one!(String.t()) :: [term()]
  def fetch_one!(query) when is_binary(query) do
    [row] = fetch_all!(query)
    row
  end

  @spec count!(String.t()) :: non_neg_integer()
  def count!(table_name) when is_binary(table_name) do
    [[count]] = fetch_all!("SELECT COUNT(*) FROM #{table_name}")
    count
  end

  @spec table_exists?(String.t()) :: boolean()
  def table_exists?(table_name) when is_binary(table_name) do
    fetch_one!(
      "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = '#{table_name}'"
    ) == [1]
  end
end
