defmodule ExRTP.Packet.Extension.AudioLevelExtension do
  @moduledoc """
  Audio Level Extension described in RFC 6464.
  """

  alias ExRTP.Packet.Extension

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
  Create new `t:ExRTP.Packet.Extension.AudioLevelExtension.t/0` struct.
  """
  @spec new(boolean(), level()) :: t()
  def new(voice, level) do
    %__MODULE__{
      voice: voice,
      level: level
    }
  end

  @impl true
  def from_raw(%Extension{data: <<voice::1, level::7, _rest::binary>>}) do
    %__MODULE__{
      level: level,
      voice: voice == 1
    }
  end

  @impl true
  def to_raw(%__MODULE__{level: level, voice: voice}, id) do
    data = <<(voice && 1) || 0::1, level::7>>
    Extension.new(id, data)
  end
end