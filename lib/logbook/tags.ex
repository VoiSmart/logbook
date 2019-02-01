defmodule Logbook.Tags do
  @moduledoc false

  @type t :: %__MODULE__{
          tags: list(atom())
        }

  @enforce_keys [:tags]
  defstruct [:tags]

  def to_string(t) do
    Enum.join(t.tags, ",")
  end
end

defimpl String.Chars, for: Logbook.Tags do
  def to_string(t) do
    Logbook.Tags.to_string(t)
  end
end
