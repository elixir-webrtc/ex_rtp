defmodule ExRTP.Packet do
  @moduledoc """
  RTP packet encoding and decoding functionalities.
  """

  alias ExRTP.Packet.Extension

  # RFC 8285 extension profiles
  @one_byte_profile 0xBEDE
  # this not always has to be 0x1000, see RFC 8285, sect. 4.3
  @two_byte_profile 0x1000

  @type uint7() :: 0..127
  @type uint8() :: 0..255
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
          payload_type: uint7(),
          sequence_number: uint16(),
          timestamp: uint32(),
          ssrc: uint32(),
          csrc: [uint32()],
          extension_profile: uint16() | nil,
          extensions: [Extension.t()],
          payload: binary(),
          padding_size: uint8()
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
  def encode(packet) do
    csrc_count = length(packet.csrc)

    header = <<
      packet.version::2,
      (packet.padding && 1) || 0::1,
      (packet.extension && 1) || 0::1,
      csrc_count::4,
      (packet.marker && 1) || 0::1,
      packet.payload_type::7,
      packet.sequence_number::16,
      packet.timestamp::32,
      packet.ssrc::32,
      encode_csrc(packet.csrc)::binary
    >>

    extension =
      if packet.extension do
        extensions = encode_extensions(packet.extension_profile, packet.extensions)
        len = div(byte_size(extensions), 4)
        <<packet.extension_profile::16, len::16, extensions::binary>>
      else
        <<>>
      end

    padding =
      if packet.padding do
        pad_len = packet.padding_size - 1
        <<0::pad_len*8, packet.padding_size>>
      else
        <<>>
      end

    header <> extension <> packet.payload <> padding
  end

  defp encode_csrc(csrc, acc \\ <<>>)
  defp encode_csrc([], acc), do: acc
  defp encode_csrc([csrc | rest], acc), do: encode_csrc(rest, <<csrc::32, acc::binary>>)

  defp encode_extensions(@one_byte_profile, extensions) do
    extensions = encode_one_byte(extensions)
    pad_len = get_pad_len(byte_size(extensions))
    <<extensions::binary, 0::pad_len*8>>
  end

  defp encode_extensions(@two_byte_profile, extensions) do
    extensions = encode_two_byte(extensions)
    pad_len = get_pad_len(byte_size(extensions))
    <<extensions::binary, 0::pad_len*8>>
  end

  defp encode_extensions(_profile, [extension]), do: extension.data

  defp encode_one_byte(extensions, acc \\ <<>>)
  defp encode_one_byte([], acc), do: acc

  defp encode_one_byte([ext | rest], acc) do
    len = byte_size(ext.data) - 1
    encode_one_byte(rest, <<ext.id::4, len::4, ext.data::binary, acc::binary>>)
  end

  defp encode_two_byte(extensions, acc \\ <<>>)
  defp encode_two_byte([], acc), do: acc

  defp encode_two_byte([ext | rest], acc) do
    len = byte_size(ext.data)
    encode_two_byte(rest, <<ext.id, len, ext.data::binary, acc::binary>>)
  end

  defp get_pad_len(len) when rem(len, 4) == 0, do: 0
  defp get_pad_len(len), do: 4 - rem(len, 4)

  @doc """
  Decodes binary into an RTP packet.

  This function assumes that the input is an RTP v2 packet,
  but it won't fail even if version is different that 2.

  If packet is too short to ba a valid v2 RTP packet, this function
  will fail with `:not_enough_data` error.
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, :not_enough_data}
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
      csrc: decode_csrc(csrc),
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

  defp decode_csrc(raw, acc \\ [])
  defp decode_csrc(<<>>, acc), do: acc

  defp decode_csrc(<<csrc::32, rest::binary>>, acc),
    do: decode_csrc(rest, [csrc | acc])

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
