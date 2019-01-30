defmodule Logbook.Backends.LogfmtTest do
  @moduledoc false
  use ExUnit.Case

  import ExUnit.CaptureLog

  require Logger

  alias Logbook.Tags

  @backend {Logbook.Backends.Logfmt, :test}

  setup_all do
    File.rm_rf!(Path.dirname("test/logs/test.log"))

    current_level = Logger.level()
    Logger.configure(level: :debug)
    Logger.add_backend(@backend)

    on_exit(fn ->
      Logger.configure(level: current_level)
      :ok = Logger.remove_backend(@backend)
    end)

    :ok
  end

  setup do
    configure(
      path: "test/logs/test.log",
      level: :debug,
      metadata_filter: nil
    )

    on_exit(fn ->
      path() && File.rm_rf!(Path.dirname(path()))
    end)
  end

  test "logs a message" do
    capture_log(fn -> Logger.debug("oh my log") end)

    log_entry = read_log()

    assert is_binary(log_entry)
    assert log_entry =~ "oh my log"
  end

  test "a log message contains default fields" do
    capture_log(fn -> Logger.debug("oh my log") end)

    log_entry = read_log()

    assert log_entry =~ "date="
    assert log_entry =~ "time="
    assert log_entry =~ "level=debug"
    assert log_entry =~ ~r/msg=\".+oh my log.+\" /
    assert log_entry =~ "module=Logbook.Backends.LogfmtTest"
    assert log_entry =~ "function=\"test a log message contains default fields/1\""
    assert log_entry =~ "file="
    assert log_entry =~ "line="
    assert log_entry =~ "vm_pid="
    assert log_entry =~ "pid="
    assert log_entry =~ "host="
    assert log_entry =~ "tags=default"
  end

  test "a log message with tags into metadata" do
    # Logbook puts tags into logger metadata :tags key
    capture_log(fn -> Logger.debug("oh my log", tags: %Tags{tags: [:foo, :bar]}) end)

    log_entry = read_log()
    assert log_entry =~ "tags=foo,bar"
    refute log_entry =~ "tags=\"[:foo, :bar"
  end

  test "can configure metadata_filter" do
    configure(metadata_filter: [md_key: true])
    capture_log(fn -> Logger.debug("shouldn't", md_key: false) end)
    capture_log(fn -> Logger.debug("should", md_key: true) end)

    refute log_has_field_value?(:msg, "shouldn't")
    assert log_has_field_value?(:msg, "should")
  end

  test "metadata_matches?/2" do
    import Logbook.Backends.Logfmt, only: [metadata_matches?: 2]

    # exact match
    assert metadata_matches?([a: 1], a: 1) == true
    # total mismatch
    assert metadata_matches?([b: 1], a: 1) == false
    # default to allow
    assert metadata_matches?([b: 1], nil) == true
    # metadata is superset of filter
    assert metadata_matches?([b: 1, a: 1], a: 1) == true
    # multiple filter keys subset of metadata
    assert metadata_matches?([c: 1, b: 1, a: 1], b: 1, a: 1) == true
    # multiple filter keys superset of metadata
    assert metadata_matches?([a: 1], b: 1, a: 1) == false
  end

  test "can reconfigure level" do
    configure(level: :info)
    capture_log(fn -> Logger.debug("hello") end)

    refute File.exists?(path())
  end

  test "can reconfigure path" do
    new_path = "test/logs/test.log.2"
    configure(path: new_path)

    assert new_path == path()
  end

  test "logs to new file after old file has been moved" do
    capture_log(fn -> Logger.debug("foo") end)
    capture_log(fn -> Logger.debug("bar") end)

    assert log_has_field_value?(:msg, "foo")
    assert log_has_field_value?(:msg, "bar")

    {"", 0} = System.cmd("mv", [path(), path() <> ".1"])

    capture_log(fn -> Logger.debug("biz") end)
    capture_log(fn -> Logger.debug("baz") end)

    assert log_has_field_value?(:msg, "biz")
    assert log_has_field_value?(:msg, "baz")
  end

  test "closes old log file after log file has been moved" do
    capture_log(fn -> Logger.debug("foo") end)
    assert has_open(path())

    new_path = path() <> ".1"
    {"", 0} = System.cmd("mv", [path(), new_path])

    assert has_open(new_path)

    capture_log(fn -> Logger.debug("bar") end)

    assert has_open(path())
    refute has_open(new_path)
  end

  test "closes old log file after path has been changed" do
    capture_log(fn -> Logger.debug("foo") end)
    assert has_open(path())

    org_path = path()
    configure(path: path() <> ".new")

    capture_log(fn -> Logger.debug("bar") end)
    assert has_open(path())
    refute has_open(org_path)
  end

  # Private helpers

  defp log_has_field_value?(field, content) do
    # poor man matching, for proper testing we should implement a decoder
    read_log()
    |> String.split("\n", trim: true)
    |> Enum.any?(fn line ->
      line =~ ~r/#{field}=.+#{content}.+ /
    end)
  end

  defp configure(opts) do
    Logger.configure_backend(@backend, opts)
  end

  defp read_log do
    File.read!(path())
  end

  defp path do
    {:ok, path} = :gen_event.call(Logger, @backend, :path)
    path
  end

  defp has_open(path) do
    has_open(:os.type(), path)
  end

  defp has_open({:unix, _}, path) do
    case System.cmd("lsof", [path]) do
      {output, 0} ->
        output =~ System.get_pid()

      _ ->
        false
    end
  end

  defp has_open(_, _) do
    false
  end
end
