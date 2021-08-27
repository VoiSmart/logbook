defmodule Logbook do
  @moduledoc false
  alias Logbook.LogTags

  @logger_levels [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]
  @logbook_levels @logger_levels ++ [:none]
  @type level ::
          :emergency
          | :alert
          | :critical
          | :error
          | :warn
          | :warning
          | :notice
          | :info
          | :debug
          | :none

  @type tag_or_tags :: atom | [atom]

  @spec set_level(tag_or_tags, level) :: :ok
  def set_level(tag_or_tags, :warn) do
    set_level(tag_or_tags, :warning)
  end

  def set_level(tag, level) when is_atom(tag) and level in @logbook_levels do
    LogTags.set_level([tag], level)
  end

  def set_level(tags, level) when is_list(tags) and level in @logbook_levels do
    LogTags.set_level(tags, level)
  end

  @spec enabled?(tag_or_tags, level) :: boolean
  def enabled?(tag_or_tags, :warn) do
    enabled?(tag_or_tags, :warning)
  end

  def enabled?(tag, level) when is_atom(tag) and level in @logbook_levels do
    enabled?([tag], level)
  end

  def enabled?(tags, level) when is_list(tags) and level in @logbook_levels do
    LogTags.enabled?(tags, level)
  end

  @spec module_enabled?(module(), level) :: boolean
  def module_enabled?(module, :warn) when is_atom(module) do
    module_enabled?(module, :warning)
  end

  def module_enabled?(module, level) when is_atom(module) and level in @logbook_levels do
    LogTags.module_enabled?(module, level)
  end

  @spec reset() :: :ok
  def reset do
    LogTags.reset()
  end

  @spec tags() :: map()
  def tags do
    LogTags.tags()
  end

  for level <- @logger_levels do
    @doc since: "2.0.0"
    defmacro unquote(level)(tag_or_tags, chardata_or_fun, metadata \\ []) do
      do_log(unquote(level), tag_or_tags, chardata_or_fun, metadata, __CALLER__)
    end

    defp macro_logger(unquote(level)) do
      level = unquote(level)

      quote do
        require Logger

        &(unquote(Logger).unquote(level) / unquote(2))
      end
    end
  end

  @deprecated "Use warning/2 instead"
  defmacro warn(tag_or_tags, chardata_or_fun, metadata \\ []) do
    do_log(:warning, tag_or_tags, chardata_or_fun, metadata, __CALLER__)
  end

  defp do_log(level, tag_or_tags, chardata_or_fun, metadata, caller) do
    logger = macro_logger(level)
    {module, tags} = macro_preprocess(tag_or_tags, caller)

    quote do
      level = unquote(level)
      logger = unquote(logger)

      # enrich metadata
      md = Keyword.put(unquote(metadata), :tags, %Logbook.Tags{tags: unquote(tags)})

      should_log =
        Logbook.enabled?(unquote(tags), level) || Logbook.module_enabled?(unquote(module), level)

      case should_log do
        false ->
          :ok

        true ->
          logger.(unquote(chardata_or_fun), md)
      end
    end
  end

  defp macro_preprocess(tag_or_tags, caller) do
    %{module: module, function: _fun, file: _file, line: _line} = caller

    tags =
      case is_list(tag_or_tags) do
        true -> tag_or_tags
        false -> [tag_or_tags]
      end

    macro_tags_must_be_atoms(tags)

    {module, tags}
  end

  defp macro_tags_must_be_atoms(tags) do
    Enum.each(tags, fn tag when is_atom(tag) -> tag end)
  end
end
