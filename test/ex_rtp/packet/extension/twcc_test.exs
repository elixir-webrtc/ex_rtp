defmodule ExRTP.Packet.Extension.TWCCTest do
  use ExUnit.Case, async: true

  alias ExRTP.Packet.Extension
  alias ExRTP.Packet.Extension.TWCC

  @number 58_123

  test "new/2" do
    extension = TWCC.new(@number)

    assert %TWCC{sequence_number: @number} = extension
  end

  describe "from_raw/1" do
    test "valid extension" do
      raw = %Extension{id: 12, data: <<@number::16>>}
      assert {:ok, extension} = TWCC.from_raw(raw)

      assert %TWCC{sequence_number: @number} = extension
    end

    test "invalid extension" do
      raw = %Extension{id: 12, data: <<@number::16, 5>>}
      assert {:error, :invalid_extension} = TWCC.from_raw(raw)
    end
  end

  test "to_raw/2" do
    raw =
      %TWCC{sequence_number: @number}
      |> TWCC.to_raw(5)

    assert %Extension{id: 5, data: <<@number::16>>} = raw
  end
end
