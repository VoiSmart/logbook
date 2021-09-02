defmodule Logbook.LogTags do
  @moduledoc false
  use GenServer

  @table_name __MODULE__

  defmodule State do
    @moduledoc false
    defstruct __default_level__: nil, table: nil
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  def set_level(tags, level) when is_list(tags) do
    GenServer.call(__MODULE__, {:set_level, tags, level})
  end

  @doc false
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  def tags do
    GenServer.call(__MODULE__, :get_tags_levels)
  end

  @doc false
  def enabled?(tag, level) when is_atom(tag) do
    cur_level = lookup_tag_maybe_update(tag)

    case compare_levels(level, cur_level) do
      :lt -> false
      _ -> true
    end
  end

  def enabled?(tags, level) when is_list(tags) do
    cur_levels = tags |> Enum.map(&lookup_tag_maybe_update/1)

    cur_levels
    |> Enum.reduce_while(false, fn cur_level, _ ->
      case compare_levels(level, cur_level) do
        :lt -> {:cont, false}
        _ -> {:halt, true}
      end
    end)
  end

  def module_enabled?(nil, _level) do
    false
  end

  def module_enabled?(module, level) do
    cur_level =
      case :ets.lookup(@table_name, module) do
        [{_module, level}] ->
          level

        [] ->
          level = default_module_level()
          GenServer.cast(__MODULE__, {:set_level, [module], level})
          level
      end

    case compare_levels(level, cur_level) do
      :lt -> false
      _ -> true
    end
  end

  @impl true
  def init(_opts) do
    state = default_state()

    table = :ets.new(@table_name, [:named_table, :protected, {:read_concurrency, true}])

    {:ok, %State{state | table: table}}
  end

  @impl true
  def handle_call(:reset, _from, %{table: table}) do
    state = default_state()
    :ets.delete_all_objects(table)

    {:reply, :ok, %State{state | table: table}}
  end

  def handle_call({:set_level, tags, level}, _from, %{table: t} = state) do
    objs =
      tags
      |> Enum.map(fn tag ->
        {tag, level}
      end)

    :ets.insert(t, objs)

    {:reply, :ok, state}
  end

  def handle_call(:get_tags_levels, _from, %{table: t} = state) do
    tags =
      t
      |> :ets.match(:"$1")
      |> Enum.map(fn [obj] -> obj end)
      |> Map.new()

    {:reply, tags, state}
  end

  @impl true
  def handle_cast({:set_level, tags, level}, %{table: t} = state) do
    objs =
      tags
      |> Enum.map(fn tag ->
        {tag, level}
      end)

    :ets.insert(t, objs)

    {:noreply, state}
  end

  defp default_state do
    %State{__default_level__: default_level()}
  end

  defp default_level do
    case Application.get_env(:logbook, :default_tag_level, :warning) do
      :warn -> :warning
      v -> v
    end
  end

  defp default_module_level do
    Application.get_env(:logbook, :default_module_level, :none)
  end

  defp compare_levels(:none, _right), do: :gt

  defp compare_levels(_left, :none), do: :lt

  defp compare_levels(left, right) do
    Logger.compare_levels(left, right)
  end

  defp lookup_tag_maybe_update(tag) do
    case :ets.lookup(@table_name, tag) do
      [{_tag, level}] ->
        level

      [] ->
        level = default_level()
        GenServer.cast(__MODULE__, {:set_level, [tag], level})
        level
    end
  end
end
