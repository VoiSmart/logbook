defmodule Logbook.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      {Logbook.LogTags, []}
    ]

    opts = [strategy: :one_for_one, name: Logbook.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
