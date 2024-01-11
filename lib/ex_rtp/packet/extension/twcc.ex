defmodule ExRTP.Packet.Extension.TWCC do
  @moduledoc """
  Transport-wide Congestion Control (TWCC) Extension
  described in `draft-holmer-rmcat-transport-wide-cc-extensions-01`.
  """

  alias ExRTP.Packet.Extension

  # not using @impl true on callbacks, as it implicitly removes documentation
  @behaviour Extension

  @typedoc """
  Struct representing TWCC Extension.
  """
  @type t() :: %__MODULE__{
          sequence_number: ExRTP.Packet.uint16()
        }

  @enforce_keys [:sequence_number]
  defstruct @enforce_keys

  @doc """
  Create new `t:ExRTP.Packet.Extension.TWCC.t/0` struct.
  """
  @spec new(ExRTP.Packet.uint16()) :: t()
  def new(sequence_number) do
    %__MODULE__{
      sequence_number: sequence_number
    }
  end

  def from_raw(%Extension{data: <<number::16>>}) do
    {:ok, %__MODULE__{sequence_number: number}}
  end

  def from_raw(%Extension{}) do
    {:error, :invalid_extension}
  end

  def to_raw(%__MODULE__{sequence_number: number}, id) do
    Extension.new(id, <<number::16>>)
  end
end
