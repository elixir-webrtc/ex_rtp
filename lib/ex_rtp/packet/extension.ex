defmodule ExRTP.Packet.Extension do
  @moduledoc """
  RTP header extension functionalities.
  """

  @typedoc """
  Struct representing raw RTP header extension.

  Can be either one-byte or two-byte extension, as specified in RFC 5285.
  In that case the `id` is a non-negative integer.
  If `id == nil`, then this is the header-extension, as specified in RFC 3550, sect. 5.3.1.
  """
  @type t() :: %__MODULE__{
          id: non_neg_integer() | nil,
          data: binary()
        }

  @enforce_keys [:id, :data]
  defstruct @enforce_keys

  @spec new(non_neg_integer() | nil, binary()) :: t()
  def new(id, data) do
    %__MODULE__{id: id, data: data}
  end
end
