defmodule Logbook.Backends.Logfmt do
  @moduledoc """
  Log format file based backend.

  This backend is opinionated for optimal support of Logbook tagged logging,
  so a tags entry is always added even if no tags (ie called by plain Logger)
  are given.

  This backend cannot be configured, all metadata is always logged, along
  with additional fields.

  Here is an example of how to configure the `Logfmt` backend in a `config/config.exs` file:

      # Configures Elixir's Logger
      config :logger,
        backends: [
          :console,
          {Logbook.Backends.Logfmt, :log_fmt_log}
        ]

      # Log formar file log
      config :logger, :log_fmt_log, path: "/var/log/somefile.log"

  """
  @behaviour :gen_event

  alias Logbook.Backends.Logfmt.Encoder

  defstruct name: nil,
            path: nil,
            use_colors: true,
            io_device: nil,
            inode: nil,
            level: nil,
            metadata: nil,
            metadata_filter: nil

  @impl true
  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
  end

  @impl true
  def handle_call({:configure, opts}, %{name: name} = state) do
    {:ok, :ok, configure(name, opts, state)}
  end

  def handle_call(:path, %{path: path} = state) do
    {:ok, {:ok, path}, state}
  end

  @impl true
  def handle_event({_level, gl, _event}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event(
        {level, _gl, {Logger, msg, ts, md}},
        %{level: min_level, metadata_filter: metadata_filter} = state
      ) do
    valid_level? = is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt

    if valid_level? and metadata_matches?(md, metadata_filter) do
      log_event(level, msg, ts, md, state)
    else
      {:ok, state}
    end
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  @impl true
  def handle_info({:DOWN, ref, _, pid, reason}, %{ref: ref}) do
    raise "device #{inspect(pid)} exited: " <> Exception.format_exit(reason)
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, %{io_device: nil}) do
    :ok
  end

  def terminate(_reason, %{io_device: io_device}) do
    File.close(io_device)
    :ok
  end

  @impl true
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  ## Helpers

  @doc false
  @spec metadata_matches?(Keyword.t(), nil | Keyword.t()) :: true | false
  def metadata_matches?(_md, nil), do: true

  # all of the filter keys are present
  def metadata_matches?(_md, []), do: true

  def metadata_matches?(md, [{key, val} | rest]) do
    case Keyword.fetch(md, key) do
      {:ok, ^val} ->
        metadata_matches?(md, rest)

      # fail on first mismatch
      _ ->
        false
    end
  end

  defp get_inode(path) do
    case File.stat(path) do
      {:ok, %File.Stat{inode: inode}} -> inode
      {:error, _} -> nil
    end
  end

  defp open_log(path) do
    with :ok <- path |> Path.dirname() |> File.mkdir_p(),
         {:ok, io_device} <- File.open(path, [:append, :utf8]) do
      {:ok, io_device, get_inode(path)}
    end
  end

  defp configure(name, opts) do
    configure(name, opts, %__MODULE__{})
  end

  defp configure(name, opts, state) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    level = Keyword.get(opts, :level)
    path = Keyword.get(opts, :path)
    use_colors = Keyword.get(opts, :use_colors, Map.get(%__MODULE__{}, :use_colors))
    metadata = Keyword.get(opts, :metadata, [])
    metadata_filter = Keyword.get(opts, :metadata_filter)

    %{
      state
      | name: name,
        path: path,
        use_colors: use_colors,
        level: level,
        metadata: metadata,
        metadata_filter: metadata_filter
    }
  end

  defp log_event(_level, _msg, _ts, _md, %__MODULE__{path: nil}) do
    raise RuntimeError, message: "Called without a valid log file path."
  end

  defp log_event(
         level,
         msg,
         ts,
         md,
         %__MODULE__{path: path, io_device: nil} = state
       )
       when is_binary(path) do
    case open_log(path) do
      {:ok, io_device, inode} ->
        log_event(level, msg, ts, md, %{
          state
          | io_device: io_device,
            inode: inode
        })

      _other ->
        # Congrats, a log entry is now lost.
        # Next log event will try to reopen.
        {:ok, state}
    end
  end

  defp log_event(
         level,
         msg,
         ts,
         md,
         %__MODULE__{path: path, io_device: io_device, inode: inode} = state
       )
       when is_binary(path) do
    if !is_nil(inode) and inode == get_inode(path) do
      output = format_entry(level, msg, ts, md, state)

      try do
        :ok = IO.write(io_device, output)
        {:ok, state}
      rescue
        ErlangError ->
          case open_log(path) do
            {:ok, io_device, inode} ->
              :ok = IO.write(io_device, output)
              {:ok, %{state | io_device: io_device, inode: inode}}

            _other ->
              # ayeee we lost a log entry, reset
              # and next entry will try to reopen file
              {:ok, %{state | io_device: nil, inode: nil}}
          end
      end
    else
      File.close(io_device)
      log_event(level, msg, ts, md, %{state | io_device: nil, inode: nil})
    end
  end

  defp format_entry(level, msg, ts, md, %{use_colors: use_colors}) do
    alias Logger.Formatter

    {date, time} = ts

    log_entry =
      [
        date: date |> Formatter.format_date(),
        time: time |> Formatter.format_time(),
        level: level,
        msg: msg |> Formatter.prune() |> highlight(use_colors),
        tags: md |> get_tags(),
        pid: md |> Keyword.get(:pid),
        module: md |> Keyword.get(:module),
        function: md |> Keyword.get(:function),
        file: md |> Keyword.get(:file),
        line: md |> Keyword.get(:line),
        vm_pid: System.get_pid(),
        host: hostname()
      ]
      |> Enum.concat(md)
      |> Enum.uniq_by(fn {k, _v} -> k end)

    [colorize(Encoder.encode(log_entry), level, use_colors) | "\n"]
  end

  defp hostname do
    {:ok, hostname} = :inet.gethostname()
    hostname
  end

  defp get_tags(md) do
    Keyword.get(md, :tags, %Logbook.Tags{tags: [:default]})
  end

  defp highlight(msg, true), do: [IO.ANSI.bright(), msg | IO.ANSI.normal()]

  defp highlight(msg, false), do: msg

  defp colorize(msg, level, true) do
    color = get_color(level)
    [IO.ANSI.format_fragment(color, true), msg | IO.ANSI.reset()]
  end

  defp colorize(msg, _level, false), do: msg

  defp get_color(:debug), do: :cyan
  defp get_color(:info), do: :normal
  defp get_color(:warn), do: :yellow
  defp get_color(:error), do: :red
  defp get_color(_), do: :normal
end
