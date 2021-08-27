defmodule Logbook.LogTagsAgent do
  @moduledoc false
  use Agent

  @doc false
  def start_link(args) do
    Agent.start_link(__MODULE__, :start_link_impl, [args], name: __MODULE__)
  end

  @doc false
  def reset do
    Agent.update(__MODULE__, __MODULE__, :reset_impl, [])
  end

  @doc false
  def set_level(tags, level) when is_list(tags) do
    Agent.update(__MODULE__, __MODULE__, :set_level_impl, [tags, level])
  end

  @doc false
  def tags do
    Agent.get(__MODULE__, __MODULE__, :tags_impl, [])
  end

  @doc false
  def enabled?(tags, level) do
    cur_levels = Agent.get_and_update(__MODULE__, __MODULE__, :enabled_impl, [tags])

    cur_levels
    |> Enum.map(fn cur_level ->
      case compare_levels(level, cur_level) do
        :lt -> false
        _ -> true
      end
    end)
    |> Enum.any?()
  end

  @doc false
  def module_enabled?(module, level) do
    cur_level = Agent.get_and_update(__MODULE__, __MODULE__, :module_enabled_impl, [module])

    case compare_levels(level, cur_level) do
      :lt -> false
      _ -> true
    end
  end

  @doc false
  def start_link_impl(_args) do
    default_state()
  end

  @doc false
  def tags_impl(state) do
    state
    |> Map.delete(:__default_level__)
  end

  @doc false
  def set_level_impl(state, tags, level) do
    Enum.reduce(tags, state, fn tag, state ->
      state
      |> Map.put(tag, level)
    end)
  end

  @doc false
  def enabled_impl(state, tags) when is_list(tags) do
    Enum.reduce(tags, {[], state}, fn tag, {res, acc_state} ->
      {level, newstate} = check_cat_enabled(acc_state, tag)
      {[level | res], newstate}
    end)
  end

  @doc false
  def module_enabled_impl(state, module) do
    state
    |> Map.get(module, nil)
    |> case do
      nil ->
        level = default_module_level()
        {level, Map.put_new(state, module, level)}

      cur_level ->
        {cur_level, state}
    end
  end

  @doc false
  def reset_impl(_state) do
    default_state()
  end

  defp default_state do
    %{__default_level__: default_level()}
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

  defp check_cat_enabled(state, tag) when is_atom(tag) do
    state
    |> Map.get(tag, nil)
    |> case do
      nil ->
        level = default_level()
        {level, Map.put_new(state, tag, level)}

      cur_level ->
        {cur_level, state}
    end
  end
end
