defmodule ExRTP.Packet.Extension.AudioLevel do
  @moduledoc """
  Audio Level Extension described in `RFC 6464`.
  """

  alias ExRTP.Packet.Extension

  # not using @impl true on callbacks, as it implicitly removes documentation
  @behaviour Extension

  @type level() :: 0..127

  @typedoc """
  Struct representing Audio Level Extension.
  """
  @type t() :: %__MODULE__{
          level: level(),
          voice: boolean()
        }

  @enforce_keys [:level, :voice]
  defstruct @enforce_keys

  @doc """
  Create new `t:ExRTP.Packet.Extension.AudioLevel.t/0` struct.
  """
  @spec new(boolean(), level()) :: t()
  def new(voice, level) do
    %__MODULE__{
      voice: voice,
      level: level
    }
  end

  def from_raw(%Extension{data: <<voice::1, level::7>>}) do
    {:ok, %__MODULE__{level: level, voice: voice == 1}}
  end

  def from_raw(%Extension{}) do
    {:error, :invalid_extension}
  end

  def to_raw(%__MODULE__{level: level, voice: voice}, id) do
    data = <<(voice && 1) || 0::1, level::7>>
    Extension.new(id, data)
  end
end
