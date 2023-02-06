defmodule Logbook.Backends.Logfmt.EncoderTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Logbook.Backends.Logfmt.Encoder

  property "Can encode any keyword list" do
    check all(keywords <- keyword_of(term())) do
      assert log_msg = Encoder.encode(keywords)
      assert is_binary(log_msg)
    end
  end

  property "Can encode any keyword list of floats" do
    check all(keywords <- keyword_of(float())) do
      assert log_msg = Encoder.encode(keywords)
      assert is_binary(log_msg)
    end
  end

  property "Can encode any keyword list of booleans" do
    check all(keywords <- keyword_of(boolean())) do
      assert log_msg = Encoder.encode(keywords)
      assert is_binary(log_msg)
    end
  end

  property "Can encode any keyword list of iolists" do
    check all(keywords <- keyword_of(iolist())) do
      assert log_msg = Encoder.encode(keywords)
      assert is_binary(log_msg)
    end
  end

  property "Can encode any keyword list of tuples" do
    check all(keywords <- keyword_of(tuple({StreamData.integer(), StreamData.binary()}))) do
      assert log_msg = Encoder.encode(keywords)
      assert is_binary(log_msg)
    end
  end

  property "Can encode any keyword list of maps" do
    check all(
            keywords <- keyword_of(map_of(StreamData.atom(:alphanumeric), term())),
            max_runs: 25
          ) do
      assert log_msg = Encoder.encode(keywords)
      assert is_binary(log_msg)
    end
  end

  property "Can encode any keyword list of structs" do
    check all(
            keywords <- keyword_of(map_of(StreamData.atom(:alphanumeric), term())),
            max_runs: 2
          ) do
      keywords =
        Enum.map(keywords, fn {k, map} ->
          {k, Map.put(map, :__struct__, __MODULE__)}
        end)

      assert log_msg = Encoder.encode(keywords)
      assert is_binary(log_msg)
    end
  end

  property "Can encode any keyword list of functions" do
    check all(keywords <- keyword_of(constant(fn x -> x end))) do
      assert log_msg = Encoder.encode(keywords)
      assert is_binary(log_msg)
    end
  end

  property "Can encode any keyword list of Ports" do
    check all(
            keywords <-
              keyword_of(
                constant(fn _ ->
                  {:ok, port} = :gen_tcp.listen(0, [])
                  port
                end)
              )
          ) do
      assert log_msg = Encoder.encode(keywords)
      assert is_binary(log_msg)
    end
  end
end
