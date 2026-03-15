defmodule ArchaeologyRush.DemoTest do
  use ExUnit.Case, async: true

  alias ArchaeologyRush.Demo

  test "run/0 renders the expected state transition summary" do
    output = Demo.run()

    assert output =~ "ArchaeologyRush demo"
    assert output =~ "progression case:"
    assert output =~ "[after dig]"
    assert output =~ "game_status=:in_progress"
    assert output =~ "artifact_status=discovered"
    assert output =~ "[after catalog]"
    assert output =~ "artifact_status=cataloged"
    assert output =~ "[after recover]"
    assert output =~ "score=20"
    assert output =~ "[after end_turn]"
    assert output =~ "turn=2"
    assert output =~ "last_action=end_turn"
    assert output =~ "winning case:"
    assert output =~ "[after complete_report]"
    assert output =~ "game_status=:won"
    assert output =~ "losing case:"
    assert output =~ "game_status={:lost, :too_many_record_misses}"
  end
end
