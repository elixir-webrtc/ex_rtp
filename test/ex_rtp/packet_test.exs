defmodule ExRTP.PacketTest do
  use ExUnit.Case, async: true

  alias ExRTP.Packet
  alias ExRTP.Packet.Extension

  @version 2
  @payload_type 111
  @sequence_number 16_895
  @timestamp 3_524_561_850
  @ssrc 0x37B8307F

  describe "decode/1" do
    test "simple packet" do
      payload = <<0, 0, 5, 0, 9>>

      packet =
        <<@version::2, 0::1, 0::1, 0::4, 1::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, payload::binary>>

      assert {:ok, decoded} = Packet.decode(packet)

      assert %Packet{
               version: 2,
               padding: false,
               extension: false,
               marker: true,
               payload_type: @payload_type,
               sequence_number: @sequence_number,
               timestamp: @timestamp,
               ssrc: @ssrc,
               csrc: [],
               extension_profile: nil,
               extensions: [],
               payload: ^payload,
               padding_size: 0
             } = decoded
    end

    test "packet too short" do
      packet =
        <<@version::2, 0::1, 0::1, 0::4, 1::1, @payload_type::7, @sequence_number::16,
          @timestamp::32>>

      assert {:error, :not_enough_data} = Packet.decode(packet)
    end

    test "packet with padding" do
      payload = <<0, 0, 5, 0, 9>>
      padding_size = 4
      padding = <<0, 0, 0, padding_size>>

      packet =
        <<@version::2, 1::1, 0::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, payload::binary, padding::binary>>

      assert {:ok, decoded} = Packet.decode(packet)

      assert %Packet{
               version: 2,
               padding: true,
               extension: false,
               marker: false,
               payload_type: @payload_type,
               sequence_number: @sequence_number,
               timestamp: @timestamp,
               ssrc: @ssrc,
               csrc: [],
               extension_profile: nil,
               extensions: [],
               payload: ^payload,
               padding_size: ^padding_size
             } = decoded
    end

    test "packet with csrc" do
      payload = <<0, 0, 5, 0, 9>>
      csrc_list = [@ssrc, @ssrc - 1, @ssrc - 12]
      csrc = for i <- csrc_list, do: <<i::32>>, into: <<>>

      packet =
        <<@version::2, 0::1, 0::1, 3::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, csrc::binary, payload::binary>>

      assert {:ok, decoded} = Packet.decode(packet)

      assert %Packet{
               version: 2,
               padding: false,
               extension: false,
               marker: false,
               payload_type: @payload_type,
               sequence_number: @sequence_number,
               timestamp: @timestamp,
               ssrc: @ssrc,
               csrc: decoded_csrc,
               extension_profile: nil,
               extensions: [],
               payload: ^payload,
               padding_size: 0
             } = decoded

      assert Enum.sort(csrc_list) == Enum.sort(decoded_csrc)
    end

    test "packet with header extension" do
      payload = <<0, 0, 5, 0, 9>>
      extension_profile = 0xBDDE
      len = 3
      content = for _ <- 1..len, do: <<0::32>>, into: <<>>
      extension = <<extension_profile::16, len::16, content::binary>>

      packet =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, payload::binary>>

      assert {:ok, decoded} = Packet.decode(packet)

      assert %Packet{
               version: 2,
               padding: false,
               extension: true,
               marker: false,
               payload_type: @payload_type,
               sequence_number: @sequence_number,
               timestamp: @timestamp,
               ssrc: @ssrc,
               csrc: [],
               extension_profile: ^extension_profile,
               extensions: [%Extension{id: nil, data: ^content}],
               payload: ^payload,
               padding_size: 0
             } = decoded
    end

    test "packet with padding, extension and csrc" do
      payload = <<0, 0, 5, 0, 9>>

      csrc_list = [@ssrc, @ssrc - 1, @ssrc - 12]
      csrc = for i <- csrc_list, do: <<i::32>>, into: <<>>

      extension_profile = 0xBDDE
      len = 3
      content = for _ <- 1..len, do: <<0::32>>, into: <<>>
      extension = <<extension_profile::16, len::16, content::binary>>

      padding_size = 4
      padding = <<0, 0, 0, padding_size>>

      packet =
        <<@version::2, 1::1, 1::1, 3::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, csrc::binary, extension::binary, payload::binary,
          padding::binary>>

      assert {:ok, decoded} = Packet.decode(packet)

      assert %Packet{
               version: 2,
               padding: true,
               extension: true,
               marker: false,
               payload_type: @payload_type,
               sequence_number: @sequence_number,
               timestamp: @timestamp,
               ssrc: @ssrc,
               csrc: decoded_csrc,
               extension_profile: ^extension_profile,
               extensions: [%Extension{id: nil, data: ^content}],
               payload: ^payload,
               padding_size: ^padding_size
             } = decoded

      assert Enum.sort(csrc_list) == Enum.sort(decoded_csrc)
    end

    test "packet with one-byte extensions" do
      payload = <<0, 0, 5, 0, 9>>
      extension_profile = 0xBEDE

      ext_1 = <<5::4, 0::4, 7>>
      decoded_ext_1 = %Extension{id: 5, data: <<7>>}
      ext_2 = <<8::4, 1::4, 3, 6>>
      decoded_ext_2 = %Extension{id: 8, data: <<3, 6>>}
      ext_3 = <<12::4, 3::4, 3, 6, 2, 3>>
      decoded_ext_3 = %Extension{id: 12, data: <<3, 6, 2, 3>>}

      # example from RFC 5285, sect. 4.2
      content = <<ext_1::binary, ext_2::binary, 0, 0, ext_3::binary>>
      extensions = [decoded_ext_1, decoded_ext_2, decoded_ext_3]

      extension = <<extension_profile::16, 3::16, content::binary>>

      packet =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, payload::binary>>

      assert {:ok, decoded} = Packet.decode(packet)

      assert %Packet{
               version: 2,
               padding: false,
               extension: true,
               marker: false,
               payload_type: @payload_type,
               sequence_number: @sequence_number,
               timestamp: @timestamp,
               ssrc: @ssrc,
               csrc: [],
               extension_profile: ^extension_profile,
               extensions: decoded_extensions,
               payload: ^payload,
               padding_size: 0
             } = decoded

      sorter = fn a, b -> a.id >= b.id end
      assert Enum.sort(extensions, sorter) == Enum.sort(decoded_extensions, sorter)
    end

    test "packet with two-byte extensions" do
      payload = <<0, 0, 5, 0, 9>>
      extension_profile = 0x1000

      ext_1 = <<5, 0>>
      decoded_ext_1 = %Extension{id: 5, data: <<>>}
      ext_2 = <<8, 1, 3>>
      decoded_ext_2 = %Extension{id: 8, data: <<3>>}
      ext_3 = <<12, 4, 3, 6, 2, 3>>
      decoded_ext_3 = %Extension{id: 12, data: <<3, 6, 2, 3>>}

      # example from RFC 5285, sect. 4.3
      content = <<ext_1::binary, ext_2::binary, 0, ext_3::binary>>
      extensions = [decoded_ext_1, decoded_ext_2, decoded_ext_3]

      extension = <<extension_profile::16, 3::16, content::binary>>

      packet =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, payload::binary>>

      assert {:ok, decoded} = Packet.decode(packet)

      assert %Packet{
               version: 2,
               padding: false,
               extension: true,
               marker: false,
               payload_type: @payload_type,
               sequence_number: @sequence_number,
               timestamp: @timestamp,
               ssrc: @ssrc,
               csrc: [],
               extension_profile: ^extension_profile,
               extensions: decoded_extensions,
               payload: ^payload,
               padding_size: 0
             } = decoded

      sorter = fn a, b -> a.id >= b.id end
      assert Enum.sort(extensions, sorter) == Enum.sort(decoded_extensions, sorter)
    end
  end
end
