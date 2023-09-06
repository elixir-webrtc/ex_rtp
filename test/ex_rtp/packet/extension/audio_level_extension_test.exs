defmodule AudioLevelExtensionTest do
  use ExUnit.Case, async: true

  alias ExRTP.Packet.Extension
  alias ExRTP.Packet.Extension.AudioLevelExtension

  test "new/2" do
    extension = AudioLevelExtension.new(true, 99)

    assert %AudioLevelExtension{voice: true, level: 99} = extension
  end

  test "from_raw/1" do
    raw = %Extension{id: 12, data: <<1::1, 88::7>>}
    extension = AudioLevelExtension.from_raw(raw)

    assert %AudioLevelExtension{voice: true, level: 88} = extension
  end

  test "to_raw/2" do
    extension = %AudioLevelExtension{voice: false, level: 81}
    raw = AudioLevelExtension.to_raw(extension, 5)

    assert %Extension{id: 5, data: <<0::1, 81::7>>} = raw
  end
end
