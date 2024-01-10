defmodule ExRTP.Packet do
  @moduledoc """
  RTP packet encoding and decoding functionalities.

  ## Examples

    ```elixir
    iex> alias ExRTP.Packet
    iex> alias ExRTP.Packet.Extension.AudioLevel
    iex> extension = AudioLevel.new(true, 120) |> AudioLevel.to_raw(5)
    iex> payload = <<3, 5, 5, 0>>
    iex> encoded =
    ...>   payload
    ...>   |> Packet.new(
    ...>     payload_type: 120,
    ...>     sequence_number: 50_000,
    ...>     timestamp: 1_000_000,
    ...>     ssrc: 500_000
    ...>   )
    ...>   |> Packet.add_extension(extension)
    ...>   |> Packet.encode()
    iex> {:ok, %Packet{payload: ^payload}} = Packet.decode(encoded)
    ```
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

  Use `new/2` to create a new RTP packet. RTP header extensions and packet
  padding should not be modified directly, but with the use of functions in this module.
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
          extensions: [Extension.t()] | binary() | nil,
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
                extensions: nil,
                padding_size: 0
              ]

  @doc """
  Creates new `t:ExRTP.Packet.t/0` struct.

  The `fields` parameter corresponds to the RTP packet header fields.
  Refer to `RFC 3550` for in-depth explanation.

  If not passed, `payload_type`, `sequence_number`, `timestamp` and
  `ssrc` will be set to `0`, as they are often expected to be set later
  during the processing of the packet.

  The `fields` keyword list may also include:
    * `csrc` (by default `[]`, must be shorter than `16`),
    * `marker` (by default `false`),
    * `padding` (by default no padding is applied)
  """
  @spec new(binary(),
          payload_type: uint7(),
          sequence_number: uint16(),
          timestamp: uint32(),
          ssrc: uint32(),
          csrc: [uint32()],
          marker: boolean(),
          padding: uint8()
        ) :: t()
  def new(payload, fields \\ []) do
    csrc = Keyword.get(fields, :csrc, [])
    if length(csrc) > 15, do: raise("CSRC list must be shorter that 16")

    packet = %__MODULE__{
      marker: Keyword.get(fields, :marker, false),
      payload_type: Keyword.get(fields, :payload_type, 0),
      sequence_number: Keyword.get(fields, :sequence_number, 0),
      timestamp: Keyword.get(fields, :timestamp, 0),
      ssrc: Keyword.get(fields, :ssrc, 0),
      csrc: csrc,
      payload: payload
    }

    case Keyword.fetch(fields, :padding) do
      {:ok, 0} -> packet
      {:ok, pad_len} -> %{packet | padding: true, padding_size: pad_len}
      :error -> packet
    end
  end

  @doc """
  Fetches extension with specified `id` from this packet.

  If no extension with `id` is found or `RFC 8285` extension mechanism is not used, this function will return `:error`.
  """
  @spec fetch_extension(t(), non_neg_integer()) :: {:ok, Extension.t()} | :error
  def fetch_extension(packet, id)

  def fetch_extension(%__MODULE__{extensions: ext}, _id) when not is_list(ext), do: :error

  def fetch_extension(packet, id) do
    case Enum.find(packet.extensions, &(&1.id == id)) do
      nil -> :error
      other -> {:ok, other}
    end
  end

  @doc """
  Sets RTP header extension (`RFC 3550`, one extension per packet) for this packet.

  If you want to use the general extension mechanism from `RFC 8285` (multiple extensions per packet),
  see `add_extension/2`.

  Note that:
    * this function will overwrite any extensions set beforehand,
    * extension must be no longer than `262_140` bytes and its length must be a multiple of `4` bytes,
    * profile value must not be `0xBEDE` or `0x1000`.
  """
  @spec set_extension(t(), uint16(), binary()) :: t()
  def set_extension(packet, profile, extension)
      when profile not in [@one_byte_profile, @two_byte_profile] and
             byte_size(extension) <= 262_140 and rem(byte_size(extension), 4) == 0 do
    %{packet | extension: true, extension_profile: profile, extensions: extension}
  end

  @doc """
  Adds RTP header extension (`RFC 8285`, multiple extensions per packet) to this packet.

  If you want to use the traditional RTP extension mechanism (one extension per packet),
  see `set_extension/3`.

  Note that: 
    * if this packet already has the traditional extension (`RFC 3550`, one extension per packet) set,
    it will be removed,
    * if the packet contained the `RFC 8285` extensions, this function will
    append the new extension without removing previous extensions.

  This function automatically decides whether to use "one byte" or "two byte" extension mechanism
  (see `RFC 8285`, sec. 4) based on the extension `data` size and its `id`:
    * if sizes of all of the extension are in range `1..16`, and the IDs are in range `1..14`, "one byte" mechanism is used,
    * if there is an extension with size in range `17..255` or equal to `0`, or with ID in range `15..255`, "two byte" mechanism is used,
    * otherwise, the extension is invalid and this function will raise.
  """
  @spec add_extension(t(), Extension.t()) :: t()
  def add_extension(packet, extension) do
    profile =
      case get_extension_type(extension) do
        :one_byte when packet.extension_profile != @two_byte_profile -> @one_byte_profile
        p when p in [:one_byte, :two_byte] -> @two_byte_profile
        :invalid -> raise "Extension #{inspect(extension)} is invalid"
      end

    extensions = if is_list(packet.extensions), do: packet.extensions, else: []
    %{packet | extension: true, extension_profile: profile, extensions: extensions ++ [extension]}
  end

  defp get_extension_type(%Extension{id: id, data: data}) do
    data_size = byte_size(data)

    cond do
      id in 1..14 and data_size in 1..16 -> :one_byte
      id in 1..255 and data_size in 0..255 -> :two_byte
      true -> :invalid
    end
  end

  @doc """
  Removes RTP header extension (or all of the extensions) form this packet.
  """
  @spec remove_extensions(t()) :: t()
  def remove_extensions(packet) do
    %{packet | extension: false, extension_profile: nil, extensions: nil}
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
  defp encode_csrc([csrc | rest], acc), do: encode_csrc(rest, <<acc::binary, csrc::32>>)

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

  defp encode_extensions(_profile, extension) when is_binary(extension), do: extension

  defp encode_one_byte(extensions, acc \\ <<>>)
  defp encode_one_byte([], acc), do: acc

  defp encode_one_byte([ext | rest], acc) do
    len = byte_size(ext.data) - 1
    encode_one_byte(rest, <<acc::binary, ext.id::4, len::4, ext.data::binary>>)
  end

  defp encode_two_byte(extensions, acc \\ <<>>)
  defp encode_two_byte([], acc), do: acc

  defp encode_two_byte([ext | rest], acc) do
    len = byte_size(ext.data)
    encode_two_byte(rest, <<acc::binary, ext.id, len, ext.data::binary>>)
  end

  defp get_pad_len(len) when rem(len, 4) == 0, do: 0
  defp get_pad_len(len), do: 4 - rem(len, 4)

  @doc """
  Decodes binary into an RTP packet.

  If RTP header extension is not used, `extensions` and `extension_profile` fields in the returned struct will be `nil`.
  Otherwise, `extensions` will be:
    * a `list`, if the general mechanism for RTP header extension from `RFC 8285` is used,
    * a `binary`, if this is a traditional header extension as defined in `RFC 3550`

  If the binary is too short to be valid, this function will return error with `:not_enough_data`.
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
  defp decode_csrc(<<>>, acc), do: Enum.reverse(acc)

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
    with {:ok, extensions} <- do_decode_extension(profile, data),
         extensions <- if(is_list(extensions), do: Enum.reverse(extensions), else: extensions) do
      packet = %{packet | extension_profile: profile, extensions: extensions}
      {:ok, rest, packet}
    end
  end

  defp decode_extension(_raw, _packet) do
    {:error, :not_enough_data}
  end

  defp do_decode_extension(@one_byte_profile, raw), do: decode_one_byte(raw)
  defp do_decode_extension(@two_byte_profile, raw), do: decode_two_byte(raw)
  defp do_decode_extension(_profile, raw), do: {:ok, raw}

  defp decode_one_byte(raw, acc \\ [])
  defp decode_one_byte(<<>>, acc), do: {:ok, acc}
  defp decode_one_byte(<<15::4, _len::4, _rest::binary>>, acc), do: {:ok, acc}
  defp decode_one_byte(<<0, rest::binary>>, acc), do: decode_one_byte(rest, acc)
  defp decode_one_byte(<<0::4, _len::4, _rest::binary>>, acc), do: {:ok, acc}

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
