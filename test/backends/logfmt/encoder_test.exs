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

  property "Can encode any keyword list of map" do
    check all(keywords <- keyword_of(map(StreamData.integer(), &Integer.to_string/1))) do
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

  property "Can encode any keyword list of port" do
    check all(keywords <- keyword_of(constant(fn x -> x end))) do
      assert log_msg = Encoder.encode(keywords)
      assert is_binary(log_msg)
    end
  end

  test "can encode a keyword with a Port" do
    {:ok, port} = :gen_tcp.listen(0, [])
    kws = [myport: port]
    assert log_msg = Encoder.encode(kws)
    assert is_binary(log_msg)
  end
end
