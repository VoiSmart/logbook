defprotocol Logbook.Backends.Logfmt.Value do
  @spec encode(value :: term) :: String.t()
  def encode(value)
end

defimpl Logbook.Backends.Logfmt.Value, for: Atom do
  def encode(atom) do
    case Atom.to_string(atom) do
      "Elixir." <> rest -> rest
      binary -> binary
    end
  end
end

defimpl Logbook.Backends.Logfmt.Value, for: BitString do
  def encode(str), do: str
end

defimpl Logbook.Backends.Logfmt.Value, for: Float do
  def encode(float), do: Float.to_string(float)
end

defimpl Logbook.Backends.Logfmt.Value, for: Function do
  def encode(fun), do: inspect(fun)
end

defimpl Logbook.Backends.Logfmt.Value, for: Integer do
  def encode(int), do: Integer.to_string(int)
end

defimpl Logbook.Backends.Logfmt.Value, for: List do
  def encode(list) do
    to_string(list)
  rescue
    _ -> inspect(list)
  end
end

defimpl Logbook.Backends.Logfmt.Value, for: Map do
  def encode(map), do: inspect(map)
end

defimpl Logbook.Backends.Logfmt.Value, for: PID do
  def encode(pid) when is_pid(pid) do
    pid |> :erlang.pid_to_list() |> Logbook.Backends.Logfmt.Value.encode()
  end
end

defimpl Logbook.Backends.Logfmt.Value, for: Port do
  def encode(port), do: inspect(port)
end

defimpl Logbook.Backends.Logfmt.Value, for: Reference do
  def encode(ref) when is_reference(ref) do
    '#Ref' ++ rest = ref |> :erlang.ref_to_list()
    rest |> Logbook.Backends.Logfmt.Value.encode()
  end
end

defimpl Logbook.Backends.Logfmt.Value, for: Tuple do
  def encode(tuple), do: inspect(tuple)
end
