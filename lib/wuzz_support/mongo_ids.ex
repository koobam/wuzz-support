defmodule WuzzSupport.MongoIds do
  @moduledoc "UUIDv4 strings as document ids: readable in URLs and topics, no ObjectId parsing."

  def uuid do
    <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)
    <<n::128>> = <<a::48, 4::4, b::12, 2::2, c::62>>
    h = n |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(32, "0")

    <<p1::binary-8, p2::binary-4, p3::binary-4, p4::binary-4, p5::binary-12>> = h
    Enum.join([p1, p2, p3, p4, p5], "-")
  end
end
