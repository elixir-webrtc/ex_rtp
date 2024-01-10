defmodule ExRTP.PacketTest do
  use ExUnit.Case, async: true
  doctest ExRTP.Packet

  alias ExRTP.Packet
  alias ExRTP.Packet.Extension

  @version 2
  @payload_type 111
  @sequence_number 16_895
  @timestamp 3_524_561_850
  @ssrc 0x37B8307F
  @payload <<0, 0, 5, 0, 9>>

  @packet Packet.new(@payload,
            payload_type: @payload_type,
            sequence_number: @sequence_number,
            timestamp: @timestamp,
            ssrc: @ssrc
          )

  describe "new/2" do
    test "with defaults" do
      packet = Packet.new(@payload)

      assert %Packet{
               version: 2,
               padding: false,
               extension: false,
               marker: false,
               payload_type: 0,
               sequence_number: 0,
               timestamp: 0,
               ssrc: 0,
               csrc: [],
               extension_profile: nil,
               extensions: nil,
               payload: @payload,
               padding_size: 0
             } = packet
    end

    test "with custom options" do
      csrc = [@ssrc, @ssrc + 5]

      packet =
        Packet.new(@payload,
          payload_type: @payload_type,
          sequence_number: @sequence_number,
          timestamp: @timestamp,
          ssrc: @ssrc,
          csrc: csrc,
          marker: true
        )

      assert %Packet{
               version: 2,
               padding: false,
               extension: false,
               marker: true,
               payload_type: @payload_type,
               sequence_number: @sequence_number,
               timestamp: @timestamp,
               ssrc: @ssrc,
               csrc: ^csrc,
               extension_profile: nil,
               extensions: nil,
               payload: @payload,
               padding_size: 0
             } = packet
    end

    test "with padding" do
      packet =
        Packet.new(@payload,
          payload_type: @payload_type,
          sequence_number: @sequence_number,
          timestamp: @timestamp,
          ssrc: @ssrc,
          padding: 8
        )

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
               extensions: nil,
               payload: @payload,
               padding_size: 8
             } = packet
    end

    test "with padding equal to 0" do
      packet =
        Packet.new(@payload,
          payload_type: @payload_type,
          sequence_number: @sequence_number,
          timestamp: @timestamp,
          ssrc: @ssrc,
          padding: 0
        )

      assert %Packet{
               version: 2,
               padding: false,
               extension: false,
               marker: false,
               payload_type: @payload_type,
               sequence_number: @sequence_number,
               timestamp: @timestamp,
               ssrc: @ssrc,
               csrc: [],
               extension_profile: nil,
               extensions: nil,
               payload: @payload,
               padding_size: 0
             } = packet
    end
  end

  describe "fetch_extension/2" do
    test "when extension exists" do
      id = 5
      extension = %Extension{id: id, data: <<0, 1, 2, 3>>}

      packet = Packet.add_extension(@packet, extension)

      assert {:ok, ^extension} = Packet.fetch_extension(packet, id)
    end

    test "when different extension exists" do
      packet = Packet.add_extension(@packet, %Extension{id: 5, data: <<0, 1, 2, 3>>})

      assert :error = Packet.fetch_extension(packet, 10)
    end

    test "when no extensions exist" do
      assert :error = Packet.fetch_extension(@packet, 10)
    end
  end

  describe "set_extension/3" do
    test "with valid extension" do
      profile = 0x1111
      extension = <<0, 1, 2, 3>>

      packet =
        @packet
        |> Packet.set_extension(profile, extension)

      assert %Packet{
               extension: true,
               extension_profile: ^profile,
               extensions: ^extension
             } = packet
    end

    test "with invalid extension" do
      # lenght is not multiple of 4 bytes
      extension = <<1, 2, 3>>
      assert_raise FunctionClauseError, fn -> Packet.set_extension(@packet, 0x1234, extension) end
    end
  end

  describe "add_extension/2" do
    test "with only one_byte extensions" do
      extension = %Extension{id: 5, data: <<1, 2, 3, 4>>}

      packet = Packet.add_extension(@packet, extension)

      assert %Packet{
               extension: true,
               extension_profile: 0xBEDE,
               extensions: [^extension]
             } = packet
    end

    test "with mixed extensions" do
      one_byte_extension = %Extension{id: 5, data: <<1, 2, 3, 4>>}
      two_byte_extension = %Extension{id: 124, data: <<1, 2, 3, 4>>}

      packet = Packet.add_extension(@packet, two_byte_extension)

      assert %Packet{
               extension: true,
               extension_profile: 0x1000,
               extensions: [^two_byte_extension]
             } = packet

      packet = Packet.add_extension(packet, one_byte_extension)

      assert %Packet{
               extension: true,
               extension_profile: 0x1000,
               extensions: [^two_byte_extension, ^one_byte_extension]
             } = packet
    end

    test "with invalid extension" do
      extension = %Extension{id: 5000, data: <<>>}
      assert_raise RuntimeError, fn -> Packet.add_extension(@packet, extension) end
    end
  end

  test "remove_extensions/1" do
    packet =
      @packet
      |> Packet.add_extension(%Extension{id: 5, data: <<0, 1, 2, 3>>})
      |> Packet.remove_extensions()

    assert %Packet{extension: false, extension_profile: nil, extensions: nil} = packet
  end

  describe "encode/1" do
    test "simple packet" do
      packet = %Packet{
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
        extensions: nil,
        payload: @payload,
        padding_size: 0
      }

      encoded = Packet.encode(packet)

      valid =
        <<@version::2, 0::1, 0::1, 0::4, 1::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, @payload::binary>>

      assert valid == encoded
    end

    test "packet with padding" do
      packet = %Packet{
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
        extensions: nil,
        payload: @payload,
        padding_size: 4
      }

      encoded = Packet.encode(packet)

      padding_size = 4
      padding = <<0, 0, 0, padding_size>>

      valid =
        <<@version::2, 1::1, 0::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, @payload::binary, padding::binary>>

      assert valid == encoded
    end

    test "packet with csrc" do
      csrc_list = [@ssrc, @ssrc - 1, @ssrc - 12]

      packet = %Packet{
        version: 2,
        padding: false,
        extension: false,
        marker: false,
        payload_type: @payload_type,
        sequence_number: @sequence_number,
        timestamp: @timestamp,
        ssrc: @ssrc,
        csrc: csrc_list,
        extension_profile: nil,
        extensions: nil,
        payload: @payload,
        padding_size: 0
      }

      encoded = Packet.encode(packet)

      csrc = for i <- csrc_list, do: <<i::32>>, into: <<>>

      valid =
        <<@version::2, 0::1, 0::1, 3::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, csrc::binary, @payload::binary>>

      assert valid == encoded
    end

    test "packet with RFC 3550 header extension" do
      extension_profile = 0xBDDE
      len = 3
      content = for _ <- 1..len, do: <<0::32>>, into: <<>>

      packet = %Packet{
        version: 2,
        padding: false,
        extension: true,
        marker: false,
        payload_type: @payload_type,
        sequence_number: @sequence_number,
        timestamp: @timestamp,
        ssrc: @ssrc,
        csrc: [],
        extension_profile: extension_profile,
        extensions: content,
        payload: @payload,
        padding_size: 0
      }

      encoded = Packet.encode(packet)

      extension = <<extension_profile::16, len::16, content::binary>>

      valid =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, @payload::binary>>

      assert valid == encoded
    end

    test "packet with padding, extension and csrc" do
      csrc_list = [@ssrc, @ssrc - 1, @ssrc - 12]
      extension_profile = 0xBDDE
      len = 3
      content = for _ <- 1..len, do: <<0::32>>, into: <<>>
      padding_size = 4

      packet = %Packet{
        version: 2,
        padding: true,
        extension: true,
        marker: false,
        payload_type: @payload_type,
        sequence_number: @sequence_number,
        timestamp: @timestamp,
        ssrc: @ssrc,
        csrc: csrc_list,
        extension_profile: extension_profile,
        extensions: content,
        payload: @payload,
        padding_size: padding_size
      }

      encoded = Packet.encode(packet)

      csrc = for i <- csrc_list, do: <<i::32>>, into: <<>>
      extension = <<extension_profile::16, len::16, content::binary>>
      padding = <<0, 0, 0, padding_size>>

      valid =
        <<@version::2, 1::1, 1::1, 3::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, csrc::binary, extension::binary, @payload::binary,
          padding::binary>>

      assert valid == encoded
    end

    test "packet with one-byte extensions" do
      extension_profile = 0xBEDE

      ext_1 = <<5::4, 0::4, 7>>
      decoded_ext_1 = %Extension{id: 5, data: <<7>>}
      ext_2 = <<8::4, 1::4, 3, 6>>
      decoded_ext_2 = %Extension{id: 8, data: <<3, 6>>}
      ext_3 = <<12::4, 3::4, 3, 6, 2, 3>>
      decoded_ext_3 = %Extension{id: 12, data: <<3, 6, 2, 3>>}
      extensions = [decoded_ext_1, decoded_ext_2, decoded_ext_3]

      packet = %Packet{
        version: 2,
        padding: false,
        extension: true,
        marker: false,
        payload_type: @payload_type,
        sequence_number: @sequence_number,
        timestamp: @timestamp,
        ssrc: @ssrc,
        csrc: [],
        extension_profile: extension_profile,
        extensions: extensions,
        payload: @payload,
        padding_size: 0
      }

      encoded = Packet.encode(packet)

      # includes two 0s of padding to be a multiple of 4 bytes
      content = <<ext_1::binary, ext_2::binary, ext_3::binary, 0, 0>>
      extension = <<extension_profile::16, 3::16, content::binary>>

      valid =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, @payload::binary>>

      assert valid == encoded
    end

    test "packet with two-byte extensions" do
      extension_profile = 0x1000

      ext_1 = <<5, 0>>
      decoded_ext_1 = %Extension{id: 5, data: <<>>}
      ext_2 = <<8, 1, 3>>
      decoded_ext_2 = %Extension{id: 8, data: <<3>>}
      ext_3 = <<58, 5, 3, 6, 2, 8, 8>>
      decoded_ext_3 = %Extension{id: 58, data: <<3, 6, 2, 8, 8>>}
      extensions = [decoded_ext_1, decoded_ext_2, decoded_ext_3]

      packet = %Packet{
        version: 2,
        padding: false,
        extension: true,
        marker: false,
        payload_type: @payload_type,
        sequence_number: @sequence_number,
        timestamp: @timestamp,
        ssrc: @ssrc,
        csrc: [],
        extension_profile: extension_profile,
        extensions: extensions,
        payload: @payload,
        padding_size: 0
      }

      encoded = Packet.encode(packet)

      # no padding as it is already multiple of 4 bytes
      content = <<ext_1::binary, ext_2::binary, ext_3::binary>>
      extension = <<extension_profile::16, 3::16, content::binary>>

      valid =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, @payload::binary>>

      assert valid == encoded
    end
  end

  describe "decode/1" do
    test "simple packet" do
      packet =
        <<@version::2, 0::1, 0::1, 0::4, 1::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, @payload::binary>>

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
               extensions: nil,
               payload: @payload,
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
      padding_size = 4
      padding = <<0, 0, 0, padding_size>>

      packet =
        <<@version::2, 1::1, 0::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, @payload::binary, padding::binary>>

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
               extensions: nil,
               payload: @payload,
               padding_size: ^padding_size
             } = decoded
    end

    test "packet with csrc" do
      csrc_list = [@ssrc, @ssrc - 1, @ssrc - 12]
      csrc = for i <- csrc_list, do: <<i::32>>, into: <<>>

      packet =
        <<@version::2, 0::1, 0::1, 3::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, csrc::binary, @payload::binary>>

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
               extensions: nil,
               payload: @payload,
               padding_size: 0
             } = decoded

      assert Enum.sort(csrc_list) == Enum.sort(decoded_csrc)
    end

    test "packet with RFC 3550 header extension" do
      extension_profile = 0xBDDE
      len = 3
      content = for _ <- 1..len, do: <<0::32>>, into: <<>>
      extension = <<extension_profile::16, len::16, content::binary>>

      packet =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, @payload::binary>>

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
               extensions: ^content,
               payload: @payload,
               padding_size: 0
             } = decoded
    end

    test "packet with padding, extension and csrc" do
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
          @timestamp::32, @ssrc::32, csrc::binary, extension::binary, @payload::binary,
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
               extensions: ^content,
               payload: @payload,
               padding_size: ^padding_size
             } = decoded

      assert Enum.sort(csrc_list) == Enum.sort(decoded_csrc)
    end

    test "packet with one-byte extensions" do
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
          @timestamp::32, @ssrc::32, extension::binary, @payload::binary>>

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
               payload: @payload,
               padding_size: 0
             } = decoded

      sorter = fn a, b -> a.id >= b.id end
      assert Enum.sort(extensions, sorter) == Enum.sort(decoded_extensions, sorter)
    end

    test "packet with two-byte extensions" do
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
          @timestamp::32, @ssrc::32, extension::binary, @payload::binary>>

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
               payload: @payload,
               padding_size: 0
             } = decoded

      sorter = fn a, b -> a.id >= b.id end
      assert Enum.sort(extensions, sorter) == Enum.sort(decoded_extensions, sorter)
    end

    test "packet with one-byte extension with id 15" do
      extension_profile = 0xBEDE

      ext_1 = <<5::4, 0::4, 7>>
      decoded_ext_1 = %Extension{id: 5, data: <<7>>}
      ext_2 = <<8::4, 1::4, 3, 6>>

      content = <<ext_1::binary, 15::4, 8::4, ext_2::binary, 0, 0>>
      extension = <<extension_profile::16, 2::16, content::binary>>

      packet =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, @payload::binary>>

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
               payload: @payload,
               padding_size: 0
             } = decoded

      assert decoded_extensions == [decoded_ext_1]
    end

    test "packet with one-byte extension with id 0 and non-0 length " do
      extension_profile = 0xBEDE

      ext_1 = <<5::4, 0::4, 7>>
      decoded_ext_1 = %Extension{id: 5, data: <<7>>}
      ext_2 = <<8::4, 1::4, 3, 6>>

      content = <<ext_1::binary, 0::4, 8::4, ext_2::binary, 0, 0>>
      extension = <<extension_profile::16, 2::16, content::binary>>

      packet =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, @payload::binary>>

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
               payload: @payload,
               padding_size: 0
             } = decoded

      assert decoded_extensions == [decoded_ext_1]
    end

    test "packet with invalid header extension" do
      extension_profile = 1234

      # length field is much longer than whole packet
      ext = <<1, 2, 3, 4>>
      extension = <<extension_profile::16, 50_000::16, ext::binary>>

      packet =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, @payload::binary>>

      assert {:error, :not_enough_data} = Packet.decode(packet)
    end

    test "packet with invalid one-byte extension" do
      extension_profile = 0xBEDE

      # data is too short, should be 15, is 3
      ext = <<5::4, 14::4, 1, 2, 3>>
      extension = <<extension_profile::16, 1::16, ext::binary>>

      packet =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, @payload::binary>>

      assert {:error, :not_enough_data} = Packet.decode(packet)
    end

    test "packet with invalid two-byte extensions" do
      extension_profile = 0x1000

      # data is too short (1 vs expected 3 bytes)
      ext = <<0, 5, 3, 1>>
      extension = <<extension_profile::16, 1::16, ext::binary>>

      packet =
        <<@version::2, 0::1, 1::1, 0::4, 0::1, @payload_type::7, @sequence_number::16,
          @timestamp::32, @ssrc::32, extension::binary, @payload::binary>>

      assert {:error, :not_enough_data} = Packet.decode(packet)
    end
  end
end
