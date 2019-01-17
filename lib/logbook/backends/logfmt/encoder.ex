defmodule Logbook.Backends.Logfmt.Encoder do
  @moduledoc """
  Encode keyword lists to a single string.

  Inspired by https://hex.pm/packages/logfmt, refactored to fit logfmt file
  logger backend needs.
  """

  alias Logbook.Backends.Logfmt.Value

  @doc false
  @spec encode(Keyword.t()) :: String.t()
  def encode(kws) when is_list(kws) do
    kws
    |> Enum.map(&encode_pair/1)
    |> Enum.join(" ")
  end

  defp encode_pair({key, value}) do
    [encode_value(key), "=", encode_value(value)] |> Enum.join()
  end

  @spec encode_value(value :: term) :: String.t()
  defp encode_value(value) do
    str = Value.encode(value)

    if String.match?(str, ~r/\s/) or String.contains?(str, "=") or String.contains?(str, "\"") do
      "\"#{str}\""
    else
      str
    end
  end
end
