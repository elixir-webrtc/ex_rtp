defmodule ExRTP.Packet.Extension.SourceDescriptionTest do
  use ExUnit.Case, async: true

  alias ExRTP.Packet.Extension
  alias ExRTP.Packet.Extension.SourceDescription

  @text "hello"
  @item_type :mid

  test "new/2" do
    extension = SourceDescription.new(@text)
    assert %SourceDescription{text: @text, type: nil} = extension

    extension = SourceDescription.new(@text, @item_type)
    assert %SourceDescription{text: @text, type: @item_type} = extension
  end

  test "from_raw/1" do
    raw = %Extension{id: 12, data: @text}
    assert {:ok, extension} = SourceDescription.from_raw(raw)

    assert %SourceDescription{text: @text, type: nil} = extension
  end

  test "to_raw/2" do
    extension = %SourceDescription{text: @text, type: @item_type}
    raw = SourceDescription.to_raw(extension, 5)

    assert %Extension{id: 5, data: @text} = raw
  end
end
