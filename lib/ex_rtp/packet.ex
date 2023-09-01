defmodule ExRTP.Packet do
  @moduledoc """
  RTP packet encoding and decoding functionalities.
  """

  alias ExRTP.Header

  @typedoc """
  Possible `decode/1` error reasons.
  """
  # TODO
  @type decode_error() :: :todo

  @type uint16() :: 0..65_535
  @type uint32() :: 0..4_294_967_295

  @typedoc """
  Struct representing an RTP packet.
  """
  @type t() :: %__MODULE__{
          version: 0..3,
          padding: boolean(),
          extension: boolean(),
          marker: boolean(),
          payload_type: 0..127,
          sequence_number: uint16(),
          timestamp: uint32(),
          ssrc: uint32(),
          csrc: [uint32()],
          # maybe not necessary
          extension_profile: uint16() | nil,
          extensions: [struct()],
          payload: binary(),
          # maybe not necessary
          padding_size: non_neg_integer()
        }

  @enforce_keys [:marker, :payload_type, :sequence_number, :timestamp, :ssrc, :csrc, :payload]
  defstruct @enforce_keys ++
              [
                version: 2,
                padding: false,
                extension: false,
                extension_profile: nil,
                extensions: [],
                padding_size: 0
              ]

  @spec new() :: t()
  def new() do
    # TODO
  end

  @doc """
  Encodes an RTP packet and returns resulting binary.
  """
  @spec encode(t()) :: binary()
  def encode(packet) do
    # TODO
  end

  @doc """
  Decodes binary into an RTP packet. 
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, decode_error()}
  def decode(raw) do
    # TODO
  end
end
