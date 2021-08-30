defmodule Logbook do
  @moduledoc ~S"""
  A category (or tags) based logger for Elixir.

  Logbook is a wrapper aroud Elixir Logger that enables a to specify one or more tags
  for each invocation in order to be able to set different log levels for each tag.

  Tagging logs is useful to track log informations around different modules and
  enable only one (or more) specific tags at different log levels than the default
  Logger instead of having (for example) all debug logs enabled.

  In the following example when calling `delete_all` and having the `:audit` tag level
  set to at least `:info`, both "Deleting user..." and "Deleting domain" logs will be produced.
  If only `:domain` or `:user` tags have log level set to `:info` only the corresponding logs
  will be produced.

      ## Example
      require Logbook

      def delete_user(user) do
        Logbook.info([:audit, :user], "Deleting user #{inspect(user)})
        # ...
      end

      def delete_domain(domain) do
        Logbook.info([:audit, :domain], "Deleting domain #{inspect(domain)})
        # ...
      end

      def delete_all(user, domain) do
        delete_domain(domain)
        delete_user(user)
      end

  Log levels for each tag can be set using `Logbook.set_level/2`:

        # For a single tag
        Logbook.set_level(:audit, :info)

        # or for many tags at once
        Logbook.set_level([:audit, :user, :domain], :info)

  Is possible to set the default level for all tags, by setting the `:default_tag_level`
  config option for `:logbook` app (defaults to `:warning`):

        import Config

        config :logbook, :default_tag_level, :warning

  The `:default_tag_level` option is used when Logbook sees tags for the first time
  during runtime and set them internally with the above level.

  As a bonus, Logbook also creates a module-level tag automatically, in order to
  be able to enable log statements at once in a single module:

      defmodule Foo
        require Logbook

        def delete_user(user) do
          Logbook.info([:audit, :user], "Deleting user #{inspect(user)})
          # ...
        end

        def delete_domain(domain) do
          Logbook.info([:audit, :domain], "Deleting domain #{inspect(domain)})
          # ...
        end
      end

  With the above example is possible to `Logbook.set_level(Foo, :info)` to enable
  all Logbook calls inside the module `Foo`.

  As with `:default_tag_level` is possible to set also default module-level logging
  with:

        import Config

        config :logbook, :default_module_level, :warning

  By default `:default_module_level` is set to `:none` (no module-level logging).

  `Logbook` supports all `Logger` levels, along with the additional `:none` level
  that disables it for the specified tag/module.

  Being a wrapper for `Logger`, if the `Logger` log level is less that `Logbook`
  log level, the logs will not be produced, because are filtered by `Logger` log levels.
  Example:

        Logger.configure(level: :warning)
        Logbook.set_level(:foo, :debug)

        Logbook.debug(:foo, "This will not be emitted")

  """
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

  @doc """
  Sets log level for the specific tag or list of tags.
  """
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

  @doc """
  Checks wheter the tag has the specified log level equal o higher than the configured one.

      iex> Logbook.set_level(:foo, :info)
      :ok
      iex> Logbook.enabled?(:foo, :debug)
      false
      iex> Logbook.enabled?(:foo, :warning)
      true

  If a list of tags is passed, returns `true` if any of the tag log level is equal or lower than
  the passed one.
  """
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

  @doc """
  Like `enabled?/2` checks if the given module has a configured log level equal
  or lower than the given level.
  """
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

  @doc """
  Returns a map containing the tags/modules seen at runtime with the corresponding
  configured log level. This list is built at runtime, so if a `Logbook` loggin fun
  has never be called, the corresponding tag will not be shown here.
  """
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
