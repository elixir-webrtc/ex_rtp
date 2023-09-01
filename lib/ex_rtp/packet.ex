defmodule ExRTP.Packet do
  @moduledoc """
  RTP packet encoding and decoding functionalities.
  """

  @typedoc """
  Possible `decode/1` error reasons.
  """
  # TODO
  @type decode_error() :: :error

  @type payload_type() :: 0..127
  @type sequence_number() :: 0..65_535
  @type timestamp() :: 0..4_294_967_295
  @type ssrc() :: 0..4_294_967_295

  @typedoc """
  Struct representing an RTP packet.
  """
  @type t() :: %__MODULE__{
          version: 0..3,
          padding: boolean(),
          extension: boolean(),
          marker: boolean(),
          payload_type: payload_type(),
          sequence_number: sequence_number(),
          timestamp: timestamp(),
          ssrc: ssrc(),
          csrc: [ssrc()],
          # maybe not necessary
          extension_profile: non_neg_integer() | nil,
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

  @doc """
  Create new RTP Packet struct.

  Use `encode/1` to encode the packet into a binary.
  """
  @spec new(boolean(), payload_type(), sequence_number(), timestamp(), ssrc(), [ssrc()], binary()) ::
          t()
  def new(marker, payload_type, sequence_number, timestamp, ssrc, csrc, payload) do
    %__MODULE__{
      marker: marker,
      payload_type: payload_type,
      sequence_number: sequence_number,
      timestamp: timestamp,
      ssrc: ssrc,
      csrc: csrc,
      payload: payload
    }
  end

  @doc """
  Encodes an RTP packet and returns resulting binary.
  """
  @spec encode(t()) :: binary()
  def encode(_packet) do
    # TODO
  end

  @doc """
  Decodes binary into an RTP packet. 
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, decode_error()}
  def decode(_raw) do
    # TODO
  end
end
