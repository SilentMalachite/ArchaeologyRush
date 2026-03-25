defmodule ArchaeologyRushWeb.ConnCase do
  @moduledoc """
  LiveView テスト用ヘルパー。
  Endpoint と PubSub をテスト環境で起動します。
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      @endpoint ArchaeologyRushWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
