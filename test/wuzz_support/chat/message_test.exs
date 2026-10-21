defmodule WuzzSupport.Chat.MessageTest do
  use ExUnit.Case, async: true

  alias WuzzSupport.Chat.Message

  test "trims the body" do
    assert Message.clean_body("  halo  ") == {:ok, "halo"}
  end

  test "rejects an empty or blank body" do
    assert Message.clean_body("") == :error
    assert Message.clean_body("   \n\t ") == :error
  end

  test "accepts exactly 2000 characters and rejects 2001" do
    assert {:ok, _} = Message.clean_body(String.duplicate("a", 2000))
    assert Message.clean_body(String.duplicate("a", 2001)) == :error
  end

  test "counts characters, not bytes" do
    assert {:ok, _} = Message.clean_body(String.duplicate("é", 2000))
  end

  test "rejects a body that is not a string" do
    assert Message.clean_body(nil) == :error
    assert Message.clean_body(42) == :error
  end

  test "builds a message from a stored document" do
    doc = %{
      "_id" => "m1",
      "conversation_id" => "c1",
      "sender_id" => "u1",
      "sender_role" => "customer",
      "body" => "halo",
      "inserted_at" => ~U[2026-10-22 00:00:00Z]
    }

    assert %Message{id: "m1", conversation_id: "c1", sender_id: "u1", body: "halo"} =
             Message.from_doc(doc)
  end
end
