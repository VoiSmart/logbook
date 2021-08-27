require Logger
require Logbook

Logger.remove_backend(:console)
Logger.configure(level: :info)
Logbook.set_level(:bench, :info)

Benchee.run(
  %{
    "logger_disabled" => fn -> Logger.debug("lets bench") end,
    "logbook_disabled" => fn -> Logbook.debug(:bench, "lets bench") end,
    "logger_enabled" => fn -> Logger.warning("lets bench") end,
    "logbook_enabled" => fn -> Logbook.warning(:bench, "lets bench") end,
  },
  time: 10,
  memory_time: 2,
  parallel: 2
)
