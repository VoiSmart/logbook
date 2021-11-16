defmodule LogbookTest do
  @moduledoc false
  use ExUnit.Case
  doctest Logbook

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

  test "function is evaluated if logged (warn/warning level)" do
    test = self()

    fun = fn ->
      send(test, :hello)
      "foo"
    end

    :ok = Logbook.set_level(:somefun, :warning)
    assert capture_log(fn -> Logbook.warn(:somefun, fun) end) =~ "foo"
    assert_receive(:hello)

    :ok = Logbook.set_level(:somefun, :warn)
    assert capture_log(fn -> Logbook.warning(:somefun, fun) end) =~ "foo"
    assert_receive(:hello)
  end

  test "function is evaluated if logged (warn level)" do
    test = self()

    fun = fn ->
      send(test, :hello)
      "foo"
    end

    :ok = Logbook.set_level(:somefun, :warn)
    assert capture_log(fn -> Logbook.warn(:somefun, fun) end) =~ "foo"

    assert_receive(:hello)
  end

  test "function is evaluated if logged (warning level)" do
    test = self()

    fun = fn ->
      send(test, :hello)
      "foo"
    end

    :ok = Logbook.set_level(:somefun, :warning)
    assert capture_log(fn -> Logbook.warning(:somefun, fun) end) =~ "foo"

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
    assert capture_log(fn -> Logbook.warning(:foocat, "foo") end) =~ "foo"
    assert capture_log(fn -> Logbook.error(:foocat, "foo") end) =~ "foo"
  end

  test "multiple tags logging" do
    assert capture_log(fn -> Logbook.error([:cat1, :cat2], "foo") end) =~ "foo"
    refute capture_log(fn -> Logbook.info([:cat1, :cat2], "foo") end) =~ "foo"

    assert %{cat1: :warning, cat2: :warning} = Logbook.tags()
  end

  test "multiple tags logging, with different levels" do
    :ok = Logbook.set_level(:cat1, :debug)
    :ok = Logbook.set_level(:cat2, :error)
    assert %{cat1: :debug, cat2: :error} = Logbook.tags()

    assert capture_log(fn -> Logbook.debug([:cat1, :cat2], "foo") end) =~ "foo"
    assert capture_log(fn -> Logbook.error([:cat1, :cat2], "foo") end) =~ "foo"

    assert capture_log(fn -> Logbook.debug(:cat1, "foo") end) =~ "foo"

    refute capture_log(fn -> Logbook.warn(:cat2, "foo") end) =~ "foo"
    refute capture_log(fn -> Logbook.warning(:cat2, "foo") end) =~ "foo"
    refute capture_log(fn -> Logbook.debug(:cat2, "foo") end) =~ "foo"
  end

  test "has correct module/fun/arity metadata in log entry" do
    defmodule TestLogbookMfa do
      @moduledoc false
      require Logbook

      def hello do
        Logbook.info(:mfa, "hello")
      end
    end

    :ok = Logbook.set_level(:mfa, :debug)
    log = capture_log([format: "$metadata", metadata: :all], &TestLogbookMfa.hello/0)
    assert log =~ "mfa=LogbookTest.TestLogbookMfa.hello/0"
    assert log =~ "module=LogbookTest.TestLogbookMfa"
    assert log =~ "logbook/test/logbook_test.exs"
  end

  test "can compile with a module attribute as tags" do
    ast =
      quote do
        defmodule ShouldCompile do
          @moduledoc false
          @log_tag :compile_test
          @log_tags [:should_compile, :compile_test]

          require Logbook

          def hello do
            Logbook.debug(@log_tag, "Hello there!")
          end

          def here do
            Logbook.debug(@log_tags, "Hello here!")
          end
        end
      end

    assert Code.eval_quoted(ast, [], __ENV__)

    :ok = Logbook.set_level(:compile_test, :debug)
    log = capture_log(fn -> apply(__MODULE__.ShouldCompile, :hello, []) end)
    assert log =~ "Hello there"
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

    test "can set metadata" do
      :ok = Logbook.set_level(:dbgcat, :debug)

      assert capture_log([format: "$metadata", metadata: :all], fn ->
               my_meta_value = :bar
               Logbook.debug(:dbgcat, "foo", foo_md: my_meta_value)
             end) =~ "foo_md=bar"
    end

    test "adds tag as metadata" do
      :ok = Logbook.set_level(:dbgcat, :debug)

      assert capture_log([format: "$metadata", metadata: :all], fn ->
               my_meta_value = :bar
               Logbook.debug(:dbgcat, "foo", foo_md: my_meta_value)
             end) =~ "tags=dbgcat"
    end

    test "adds multiple tags as metadata" do
      :ok = Logbook.set_level(:dbgcat, :debug)

      assert capture_log([format: "$metadata", metadata: :all], fn ->
               my_meta_value = :bar
               Logbook.debug([:dbgcat, :anothercat], "foo", foo_md: my_meta_value)
             end) =~ "tags=dbgcat,anothercat"
    end

    test "adds multiple tags and custom data as metadata" do
      :ok = Logbook.set_level(:dbgcat, :debug)

      res =
        capture_log([format: "$metadata", metadata: :all], fn ->
          my_meta_value = :bar
          Logbook.debug([:dbgcat, :anothercat], "foo", foo_md: my_meta_value, bar: :baz)
        end)

      assert res =~ "tags=dbgcat,anothercat"
      assert res =~ "foo_md=bar"
      assert res =~ "bar=baz"
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

  describe "notice/2" do
    test "log level enabled for tag" do
      :ok = Logbook.set_level(:noticecat, :notice)

      assert capture_log(fn -> Logbook.notice(:noticecat, "foo") end) =~ "foo"
    end

    test "log level lower than configured" do
      :ok = Logbook.set_level(:infocat, :warn)

      refute capture_log(fn -> Logbook.notice(:noticecat, "foo") end) =~ "foo"
    end

    test "log disabled for tag" do
      :ok = Logbook.set_level(:infocat, :none)

      refute capture_log(fn -> Logbook.notice(:noticecat, "foo") end) =~ "foo"
    end

    test "module level log" do
      :ok = Logbook.set_level(__MODULE__, :notice)

      assert capture_log(fn -> Logbook.notice(:noticecat, "foo") end) =~ "foo"
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

  describe "warning/2" do
    test "log level enabled for tag" do
      :ok = Logbook.set_level(:warningcat, :warn)

      assert capture_log(fn -> Logbook.warning(:warningcat, "foo") end) =~ "foo"
    end

    test "log level lower than configured for tag" do
      :ok = Logbook.set_level(:warningcat, :error)

      refute capture_log(fn -> Logbook.warning(:warningcat, "foo") end) =~ "foo"
    end

    test "log disabled for tag" do
      :ok = Logbook.set_level(:warningcat, :none)

      refute capture_log(fn -> Logbook.warning(:warningcat, "foo") end) =~ "foo"
    end

    test "module level log" do
      :ok = Logbook.set_level(__MODULE__, :warn)

      assert capture_log(fn -> Logbook.warning(:warningcat, "foo") end) =~ "foo"
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

  describe "critical/2" do
    test "log level enabled for tag" do
      :ok = Logbook.set_level(:criticalcat, :critical)

      assert capture_log(fn -> Logbook.critical(:criticalcat, "foo") end) =~ "foo"
    end

    test "log disabled for tag" do
      :ok = Logbook.set_level(:criticalcat, :none)

      refute capture_log(fn -> Logbook.critical(:criticalcat, "foo") end) =~ "foo"
    end

    test "log level lower than configured for tag" do
      :ok = Logbook.set_level(:criticalcat, :alert)

      refute capture_log(fn -> Logbook.critical(:criticalcat, "foo") end) =~ "foo"
    end

    test "module level log" do
      :ok = Logbook.set_level(__MODULE__, :critical)

      assert capture_log(fn -> Logbook.critical(:criticalcat, "foo") end) =~ "foo"
    end
  end

  describe "alert/2" do
    test "log level enabled for tag" do
      :ok = Logbook.set_level(:alertcat, :alert)

      assert capture_log(fn -> Logbook.alert(:alertcat, "foo") end) =~ "foo"
    end

    test "log disabled for tag" do
      :ok = Logbook.set_level(:alertcat, :none)

      refute capture_log(fn -> Logbook.alert(:alertcat, "foo") end) =~ "foo"
    end

    test "log level lower than configured for tag" do
      :ok = Logbook.set_level(:alertcat, :emergency)

      refute capture_log(fn -> Logbook.alert(:alertcat, "foo") end) =~ "foo"
    end

    test "module level log" do
      :ok = Logbook.set_level(__MODULE__, :alert)

      assert capture_log(fn -> Logbook.alert(:alertcat, "foo") end) =~ "foo"
    end
  end

  describe "emergency/2" do
    test "log level enabled for tag" do
      :ok = Logbook.set_level(:emergencycat, :emergency)

      assert capture_log(fn -> Logbook.emergency(:emergencycat, "foo") end) =~ "foo"
    end

    test "log disabled for tag" do
      :ok = Logbook.set_level(:alertcat, :none)

      refute capture_log(fn -> Logbook.emergency(:alertcat, "foo") end) =~ "foo"
    end

    test "module level log" do
      :ok = Logbook.set_level(__MODULE__, :emergency)

      assert capture_log(fn -> Logbook.emergency(:alertcat, "foo") end) =~ "foo"
    end
  end
end
