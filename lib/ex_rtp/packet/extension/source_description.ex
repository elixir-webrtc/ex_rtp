defmodule ExRTP.Packet.Extension.SourceDescription do
  @moduledoc """
  Source Description (SDES) Extension described in `RFC 7941`.
  """

  alias ExRTP.Packet.Extension

  # not using @impl true on callbacks, as it implicitly removes documentation
  @behaviour Extension

  @typedoc """
  Struct representing SDES Extension.

  The `type` field is is purely informational and ignored, when encoding/decoding the extension,
  as the SDES item types are determined by the header extension ID value, which is dynamically
  assigned in signaling and passed to the `to_raw/2` function.
  """
  @type t() :: %__MODULE__{
          type: atom() | nil,
          text: binary()
        }

  @enforce_keys [:text]
  defstruct [:type] ++ @enforce_keys

  @doc """
  Create new `t:ExRTP.Packet.Extension.SourceDescription.t/0` struct.
  """
  @spec new(binary(), atom() | nil) :: t()
  def new(text, type \\ nil) do
    %__MODULE__{
      type: type,
      text: text
    }
  end

  def from_raw(%Extension{data: data}) do
    {:ok, %__MODULE__{text: data}}
  end

  def to_raw(%__MODULE__{text: text}, id) do
    Extension.new(id, text)
  end
end
