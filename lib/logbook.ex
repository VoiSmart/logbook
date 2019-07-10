defmodule Logbook do
  @moduledoc false
  alias Logbook.LogTags

  @spec set_level(atom, :info | :warn | :error | :debug | :none) :: :ok
  def set_level(tag, level) when is_atom(tag) do
    LogTags.set_level([tag], level)
  end

  @spec set_level([atom], :info | :warn | :error | :debug | :none) :: :ok
  def set_level(tags, level) when is_list(tags) do
    LogTags.set_level(tags, level)
  end

  @spec reset() :: :ok
  def reset do
    LogTags.reset()
  end

  @spec tags() :: map()
  def tags do
    LogTags.tags()
  end

  defmacro info(tag_or_tags, chardata_or_fun, metadata \\ []) do
    do_log(:info, tag_or_tags, chardata_or_fun, metadata, __CALLER__)
  end

  defmacro warn(tag_or_tags, chardata_or_fun, metadata \\ []) do
    do_log(:warn, tag_or_tags, chardata_or_fun, metadata, __CALLER__)
  end

  defmacro error(tag_or_tags, chardata_or_fun, metadata \\ []) do
    do_log(:error, tag_or_tags, chardata_or_fun, metadata, __CALLER__)
  end

  defmacro debug(tag_or_tags, chardata_or_fun, metadata \\ []) do
    do_log(:debug, tag_or_tags, chardata_or_fun, metadata, __CALLER__)
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
        LogTags.enabled?(unquote(tags), level) || LogTags.module_enabled?(unquote(module), level)

      case should_log do
        false ->
          :ok

        true ->
          logger.(unquote(chardata_or_fun), md)
      end
    end
  end

  defp macro_logger(:debug) do
    quote do
      require Logger

      &Logger.debug/2
    end
  end

  defp macro_logger(:info) do
    quote do
      require Logger

      &Logger.info/2
    end
  end

  defp macro_logger(:warn) do
    quote do
      require Logger

      &Logger.warn/2
    end
  end

  defp macro_logger(:error) do
    quote do
      require Logger

      &Logger.error/2
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
