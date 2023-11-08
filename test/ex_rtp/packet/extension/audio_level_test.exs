defmodule ExRTP.Packet.Extension.AudioLevelTest do
  use ExUnit.Case, async: true

  alias ExRTP.Packet.Extension
  alias ExRTP.Packet.Extension.AudioLevel

  test "new/2" do
    extension = AudioLevel.new(true, 99)

    assert %AudioLevel{voice: true, level: 99} = extension
  end

  describe "from_raw/1" do
    test "valid extension" do
      raw = %Extension{id: 12, data: <<1::1, 88::7>>}
      assert {:ok, extension} = AudioLevel.from_raw(raw)

      assert %AudioLevel{voice: true, level: 88} = extension
    end

    test "invalid extension" do
      raw = %Extension{id: 12, data: <<1::1, 88::7, 5>>}
      assert {:error, :invalid_extension} = AudioLevel.from_raw(raw)
    end
  end

  test "to_raw/2" do
    extension = %AudioLevel{voice: false, level: 81}
    raw = AudioLevel.to_raw(extension, 5)

    assert %Extension{id: 5, data: <<0::1, 81::7>>} = raw
  end
end
