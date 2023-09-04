defmodule ExRTP.Packet do
  @moduledoc """
  RTP packet encoding and decoding functionalities.
  """

  alias ExRTP.Packet.Extension

  # RFC 8285 extension profiles
  @one_byte_profile 0xBEDE
  # this not always has to be 0x1000, see RFC 8285, sect. 4.3
  @two_byte_profile 0x1000

  @typedoc """
  Possible `decode/1` error reasons.

  * `:not_enough_data` - provided binary is too short to be a valid RTP packet
  """
  # TODO
  @type decode_error() ::
          :not_enough_data

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

  @enforce_keys [:payload_type, :sequence_number, :timestamp, :ssrc, :payload]
  defstruct @enforce_keys ++
              [
                version: 2,
                padding: false,
                extension: false,
                marker: false,
                csrc: [],
                extension_profile: nil,
                extensions: [],
                padding_size: 0
              ]

  @doc """
  Create new RTP Packet struct.

  Use `encode/1` to encode the packet into a binary.
  """
  @spec new() :: t()
  def new() do
    # TODO
    %__MODULE__{
      payload_type: 0,
      sequence_number: 0,
      timestamp: 0,
      ssrc: 0,
      payload: <<>>
    }
  end

  @doc """
  Encodes an RTP packet and returns resulting binary.
  """
  @spec encode(t()) :: binary()
  def encode(_packet) do
    # TODO
    <<>>
  end

  @doc """
  Decodes binary into an RTP packet.

  This function assumes that the input is an RTP v2 packet,
  but it won't fail even if version is different that 2.
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, decode_error()}
  def decode(raw)

  def decode(<<
        version::2,
        padding::1,
        extension::1,
        csrc_count::4,
        marker::1,
        payload_type::7,
        sequence_number::16,
        timestamp::32,
        ssrc::32,
        # csrc = 32 bits * csrc_count
        csrc::binary-size(4 * csrc_count),
        rest::binary
      >>) do
    packet = %__MODULE__{
      version: version,
      padding: padding == 1,
      extension: extension == 1,
      marker: marker == 1,
      payload_type: payload_type,
      sequence_number: sequence_number,
      timestamp: timestamp,
      ssrc: ssrc,
      csrc: get_csrc(csrc),
      payload: <<>>
    }

    with {:ok, rest, packet} <- strip_padding(rest, packet),
         {:ok, rest, packet} <- decode_extension(rest, packet) do
      {:ok, %{packet | payload: rest}}
    end
  end

  def decode(_raw) do
    {:error, :not_enough_data}
  end

  defp get_csrc(raw, acc \\ [])
  defp get_csrc(<<>>, acc), do: acc
  defp get_csrc(<<csrc::32, rest::binary>>, acc), do: get_csrc(rest, [csrc | acc])

  defp strip_padding(raw, %__MODULE__{padding: false} = packet) do
    {:ok, raw, packet}
  end

  defp strip_padding(raw, packet) do
    size = byte_size(raw)

    with <<_rest::binary-size(size - 1), len>> <- raw,
         <<rest::binary-size(^size - ^len), _rest::binary>> <- raw do
      {:ok, rest, %{packet | padding_size: len}}
    else
      _other -> {:error, :not_enough_data}
    end
  end

  defp decode_extension(raw, %__MODULE__{extension: false} = packet) do
    {:ok, raw, packet}
  end

  defp decode_extension(
         <<
           profile::16,
           len::16,
           # extension = 32 bits * len
           data::binary-size(4 * len),
           rest::binary
         >>,
         packet
       ) do
    with {:ok, extensions} <- do_decode_extension(profile, data) do
      packet = %{packet | extension_profile: profile, extensions: extensions}
      {:ok, rest, packet}
    end
  end

  defp decode_extension(_raw, _packet) do
    {:error, :not_enough_data}
  end

  defp do_decode_extension(@one_byte_profile, raw), do: decode_one_byte(raw)
  defp do_decode_extension(@two_byte_profile, raw), do: decode_two_byte(raw)
  defp do_decode_extension(_profile, raw), do: {:ok, [Extension.new(nil, raw)]}

  defp decode_one_byte(raw, acc \\ [])
  defp decode_one_byte(<<>>, acc), do: {:ok, acc}
  defp decode_one_byte(<<15, _rest::binary>>, acc), do: {:ok, acc}
  defp decode_one_byte(<<0, rest::binary>>, acc), do: decode_one_byte(rest, acc)

  defp decode_one_byte(<<id::4, len::4, data::binary-size(len + 1), rest::binary>>, acc) do
    decode_one_byte(rest, [Extension.new(id, data) | acc])
  end

  defp decode_one_byte(_raw, _acc), do: {:error, :not_enough_data}

  defp decode_two_byte(raw, acc \\ [])
  defp decode_two_byte(<<>>, acc), do: {:ok, acc}
  defp decode_two_byte(<<0, rest::binary>>, acc), do: decode_two_byte(rest, acc)

  defp decode_two_byte(<<id, len, data::binary-size(len), rest::binary>>, acc) do
    decode_two_byte(rest, [Extension.new(id, data) | acc])
  end

  defp decode_two_byte(_raw, _acc), do: {:error, :not_enough_data}
end
