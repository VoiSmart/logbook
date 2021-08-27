defmodule TagsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Logbook.Tags

  test "can convert tags struct to string" do
    test_data()
    |> Enum.each(fn {data, result} ->
      assert Tags.to_string(data) == result
    end)
  end

  test "adds protocol implementation for String.Chars" do
    test_data()
    |> Enum.each(fn {data, result} ->
      assert "#{data}" == result
    end)
  end

  defp test_data do
    [
      {%Tags{tags: []}, ""},
      {%Tags{tags: [:tag1]}, "tag1"},
      {%Tags{tags: [:tag1, :tag2]}, "tag1,tag2"}
    ]
  end
end
