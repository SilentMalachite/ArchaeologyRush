defmodule ArchaeologyRushTest do
  use ExUnit.Case, async: true

  describe "hello/0" do
    test "returns :world" do
      assert ArchaeologyRush.hello() == :world
    end
  end

  describe "test runtime configuration" do
    test "does not auto-start the repo and uses a test sqlite database" do
      assert Application.fetch_env!(:archaeology_rush, :start_repo) == false

      repo_config = Application.fetch_env!(:archaeology_rush, ArchaeologyRush.Repo)

      assert repo_config[:pool_size] == 1
      assert String.ends_with?(repo_config[:database], "archaeology_rush_test.sqlite3")
      assert repo_config[:busy_timeout] == 5_000
    end
  end
end
