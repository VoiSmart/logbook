defmodule Logbook.Formatters.Logfmt.Encoder do
  @moduledoc false

  # Encode keyword lists to a single string.
  # Inspired by https://hex.pm/packages/logfmt

  alias __MODULE__.Value

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
    str =
      value
      |> Value.encode()
      |> escape()

    if String.match?(str, ~r/\s/) or String.contains?(str, "=") do
      "\"#{str}\""
    else
      str
    end
  end

  defp escape(string),
    do: escape(string, "")

  defp escape("", acc), do: acc

  defp escape(<<"\t", rest::binary>>, acc),
    do: escape(rest, <<acc::binary, "\\t">>)

  defp escape(<<"\n", rest::binary>>, acc),
    do: escape(rest, <<acc::binary, "\\n">>)

  defp escape(<<"\r", rest::binary>>, acc),
    do: escape(rest, <<acc::binary, "\\r">>)

  defp escape(<<"\"", rest::binary>>, acc),
    do: escape(rest, <<acc::binary, "\\\"">>)

  defp escape(<<"\\", rest::binary>>, acc),
    do: escape(rest, <<acc::binary, "\\\\">>)

  defp escape(<<c, rest::binary>>, acc),
    do: escape(rest, <<acc::binary, c>>)
end
