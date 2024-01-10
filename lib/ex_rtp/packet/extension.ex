defmodule ExRTP.Packet.Extension do
  @moduledoc """
  RTP header extension functionalities.
  """

  @typedoc """
  Struct representing raw RTP header extension as defined in `RFC 8285`.
  """
  @type t() :: %__MODULE__{
          id: non_neg_integer() | nil,
          data: binary()
        }

  @enforce_keys [:id, :data]
  defstruct @enforce_keys

  @doc """
  Converts extension struct to raw extension which can be used
  in `ExRTP.Packet.add_extension/2`.
  """
  @callback to_raw(extension :: struct(), id :: non_neg_integer()) :: t()

  @doc """
  Converts raw extension to extension struct.
  """
  @callback from_raw(raw :: t()) :: {:ok, struct()} | {:error, :invalid_extension}

  @doc """
  Create new `t:ExRTP.Packet.Extension.t/0` struct.
  """
  @spec new(non_neg_integer() | nil, binary()) :: t()
  def new(id, data) do
    %__MODULE__{id: id, data: data}
  end
end
