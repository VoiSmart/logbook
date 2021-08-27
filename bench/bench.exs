require Logger
require Logbook

Logger.configure(level: :emergency)
Logbook.set_level(:bench, :debug)

Benchee.run(
  %{
    "logger" => fn -> Logger.debug("lets bench") end,
    "logbook" => fn -> Logbook.debug(:bench, "lets bench") end,
  },
  time: 10,
  memory_time: 2
)
