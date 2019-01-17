defmodule LogbookTest do
  @moduledoc false
  use ExUnit.Case

  import ExUnit.CaptureLog

  require Logbook

  setup do
    Logbook.reset()
  end

  test "reset/0" do
    :ok = Logbook.set_level(:baz, :debug)
    assert capture_log(fn -> Logbook.debug(:baz, "foo") end) =~ "foo"

    :ok = Logbook.reset()
    refute capture_log(fn -> Logbook.debug(:baz, "foo") end) =~ "foo"
  end

  test "tags/0" do
    assert Logbook.tags() == %{}

    :ok = Logbook.set_level(:any, :info)
    assert Logbook.tags() == %{any: :info}
  end

  test "function is not evaluated if not logged" do
    test = self()

    fun = fn ->
      send(test, :hello)
      "foo"
    end

    refute capture_log(fn -> Logbook.debug(:somefun, fun) end) =~ "foo"

    refute_receive(:hello)
  end

  test "function is evaluated if logged" do
    test = self()

    fun = fn ->
      send(test, :hello)
      "foo"
    end

    :ok = Logbook.set_level(:somefun, :warn)
    assert capture_log(fn -> Logbook.warn(:somefun, fun) end) =~ "foo"

    assert_receive(:hello)
  end

  test "inspect is not evaluated if not logged" do
    test = self()

    refute capture_log(fn -> Logbook.debug(:somefun, "#{inspect(send(test, :hellothere))}") end) =~
             "hellothere"

    refute_receive(:hellothere)
  end

  test "inspect is evaluated if logged" do
    test = self()

    :ok = Logbook.set_level(:somefun, :debug)

    assert capture_log(fn -> Logbook.debug(:somefun, "#{inspect(send(test, :hellothere))}") end) =~
             "hellothere"

    assert_receive(:hellothere)
  end

  test "default level for any tag" do
    # default level is warn
    refute capture_log(fn -> Logbook.debug(:foocat, "foo") end) =~ "foo"
    refute capture_log(fn -> Logbook.info(:foocat, "foo") end) =~ "foo"

    assert capture_log(fn -> Logbook.warn(:foocat, "foo") end) =~ "foo"
    assert capture_log(fn -> Logbook.error(:foocat, "foo") end) =~ "foo"
  end

  test "multiple tags logging" do
    assert capture_log(fn -> Logbook.error([:cat1, :cat2], "foo") end) =~ "foo"
    refute capture_log(fn -> Logbook.info([:cat1, :cat2], "foo") end) =~ "foo"

    assert %{cat1: :warn, cat2: :warn} = Logbook.tags()
  end

  test "multiple tags logging, with different levels" do
    :ok = Logbook.set_level(:cat1, :debug)
    :ok = Logbook.set_level(:cat2, :error)
    assert %{cat1: :debug, cat2: :error} = Logbook.tags()

    assert capture_log(fn -> Logbook.debug([:cat1, :cat2], "foo") end) =~ "foo"
    assert capture_log(fn -> Logbook.error([:cat1, :cat2], "foo") end) =~ "foo"

    assert capture_log(fn -> Logbook.debug(:cat1, "foo") end) =~ "foo"

    refute capture_log(fn -> Logbook.warn(:cat2, "foo") end) =~ "foo"
    refute capture_log(fn -> Logbook.debug(:cat2, "foo") end) =~ "foo"
  end

  describe "set_level/2" do
    test "sets a single tag level" do
      Logbook.set_level(:a_single_cat, :error)

      assert %{a_single_cat: :error} = Logbook.tags()
    end

    test "sets multiple tags level at once" do
      Logbook.set_level([:a_cat, :another_cat], :error)

      assert %{a_cat: :error, another_cat: :error} = Logbook.tags()
    end
  end

  describe "debug/2" do
    test "log level enabled for tag" do
      :ok = Logbook.set_level(:dbgcat, :debug)

      assert capture_log(fn -> Logbook.debug(:dbgcat, "foo") end) =~ "foo"
    end

    test "log level lower than configured" do
      :ok = Logbook.set_level(:dbgcat, :error)

      refute capture_log(fn -> Logbook.debug(:dbgcat, "foo") end) =~ "foo"
    end

    test "log disabled for tag" do
      :ok = Logbook.set_level(:dbgcat, :none)

      refute capture_log(fn -> Logbook.debug(:dbgcat, "foo") end) =~ "foo"
    end

    test "module level log" do
      :ok = Logbook.set_level(__MODULE__, :debug)

      assert capture_log(fn -> Logbook.debug(:dbgcat, "foo") end) =~ "foo"
    end
  end

  describe "info/2" do
    test "log level enabled for tag" do
      :ok = Logbook.set_level(:infocat, :info)

      assert capture_log(fn -> Logbook.info(:infocat, "foo") end) =~ "foo"
    end

    test "log level lower than configured" do
      :ok = Logbook.set_level(:infocat, :warn)

      refute capture_log(fn -> Logbook.info(:infocat, "foo") end) =~ "foo"
    end

    test "log disabled for tag" do
      :ok = Logbook.set_level(:infocat, :none)

      refute capture_log(fn -> Logbook.info(:infocat, "foo") end) =~ "foo"
    end

    test "module level log" do
      :ok = Logbook.set_level(__MODULE__, :info)

      assert capture_log(fn -> Logbook.info(:infocat, "foo") end) =~ "foo"
    end
  end

  describe "warn/2" do
    test "log level enabled for tag" do
      :ok = Logbook.set_level(:warningcat, :warn)

      assert capture_log(fn -> Logbook.warn(:warningcat, "foo") end) =~ "foo"
    end

    test "log level lower than configured for tag" do
      :ok = Logbook.set_level(:warningcat, :error)

      refute capture_log(fn -> Logbook.warn(:warningcat, "foo") end) =~ "foo"
    end

    test "log disabled for tag" do
      :ok = Logbook.set_level(:warningcat, :none)

      refute capture_log(fn -> Logbook.warn(:warningcat, "foo") end) =~ "foo"
    end

    test "module level log" do
      :ok = Logbook.set_level(__MODULE__, :warn)

      assert capture_log(fn -> Logbook.warn(:warningcat, "foo") end) =~ "foo"
    end
  end

  describe "error/2" do
    test "log level enabled for tag" do
      :ok = Logbook.set_level(:errcat, :error)

      assert capture_log(fn -> Logbook.error(:errcat, "foo") end) =~ "foo"
    end

    test "log disabled for tag" do
      :ok = Logbook.set_level(:errcat, :none)

      refute capture_log(fn -> Logbook.error(:errcat, "foo") end) =~ "foo"
    end

    test "module level log" do
      :ok = Logbook.set_level(__MODULE__, :error)

      assert capture_log(fn -> Logbook.error(:errcat, "foo") end) =~ "foo"
    end
  end
end
