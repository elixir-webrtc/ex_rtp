defmodule ExRTP.Packet.Extension do
  @moduledoc """
  RTP header extension functionalities.
  """

  @typedoc """
  Struct representing raw RTP header extension.

  Can be either:
    * header extension, as specified in `RFC 3550`, then `id` is equal to `nil`
    * one-byte or two-byte extension, as specified `RFC 5285`
  """
  @type t() :: %__MODULE__{
          id: non_neg_integer() | nil,
          data: binary()
        }

  @enforce_keys [:id, :data]
  defstruct @enforce_keys

  @doc """
  Create new `t:ExRTP.Packet.Extension.t/0` struct.
  """
  @spec new(non_neg_integer() | nil, binary()) :: t()
  def new(id, data) do
    %__MODULE__{id: id, data: data}
  end
end
