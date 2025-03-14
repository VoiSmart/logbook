defmodule Logbook.Formatters.Logfmt do
  @moduledoc """
  A logfmt formatter backend for the Elixir console logger backend, tailored
  to Logbook needs.

  Ideally it should be used with the `metadata: :all` option of the console
  backend.

  The log line is made of the following keys:
  - `date`: date of the entry, in YYYY-MM-DD format.
  - `time`: time of the event, in hh:mm:ss.msec.
  - `level`: the log level.
  - `msg`: the actual log message.
  - `tag`: Logbook specific: comma separated list of logbook tags, fallbacks to
           `default` if the log entry has no tags.
  - `module`: module emitting the log.
  - `function`: function emitting the log, in the form function/arity.
  - `vm_pid`: OS pid of the erlang vm.
  - `host`: hostname of the system, as returned from `:inet.gethostname/0`.

  Remainig metadata is appended to this list. Note that the `:mfa` key is dropped
  since `module` and `function` are already reported.
  """
  alias Logger.Formatter
  alias __MODULE__.Encoder

  @spec format(atom, IO.chardata(), Logger.Formatter.date_time_ms(), keyword()) :: IO.chardata()
  def format(level, msg, {_, _} = timestamp, md) do
    {date, time} = timestamp

    log_entry =
      [
        date: date |> Formatter.format_date(),
        time: time |> Formatter.format_time(),
        level: level,
        msg: msg |> Formatter.prune(),
        tags: md |> get_tags()
      ]
      |> add_module(md)
      |> add_function(md)
      |> Enum.concat(
        vm_pid: System.pid(),
        host: hostname()
      )
      |> Enum.concat(md)
      |> Keyword.drop([:mfa])
      |> Enum.uniq_by(fn {k, _v} -> k end)

    Encoder.encode(log_entry) |> add_newline()
  end

  defp add_module(log_entry, md) do
    case Keyword.get(md, :mfa) do
      nil -> log_entry
      {mod, _, _} -> Enum.concat(log_entry, module: mod)
    end
  end

  defp add_function(log_entry, md) do
    case Keyword.get(md, :mfa) do
      nil ->
        log_entry

      {_, fun, arity} ->
        fa = [Atom.to_string(fun), "/", Integer.to_string(arity)]
        Enum.concat(log_entry, function: fa)
    end
  end

  defp hostname do
    # TODO cache me?
    {:ok, hostname} = :inet.gethostname()

    hostname
  end

  defp get_tags(md) do
    Keyword.get(md, :tags, "default")
  end

  defp add_newline(log) do
    [log, ?\n]
  end
end
