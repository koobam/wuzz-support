defmodule WuzzSupport.Chat.Conversation do
  @moduledoc "A thread between one customer and either support or one outlet."
  defstruct [:id, :customer_id, :kind, :outlet_id, :last_message_at, :inserted_at, status: "open"]

  @kinds ["support", "outlet"]

  def from_doc(nil), do: nil

  def from_doc(doc) do
    %__MODULE__{
      id: doc["_id"],
      customer_id: doc["customer_id"],
      kind: doc["kind"],
      outlet_id: doc["outlet_id"],
      status: doc["status"],
      last_message_at: doc["last_message_at"],
      inserted_at: doc["inserted_at"]
    }
  end

  @doc "Validates the fields a customer controls; returns a map of field => messages."
  def validate(kind, outlet_id) do
    cond do
      kind not in @kinds ->
        {:error, %{kind: ["must be support or outlet"]}}

      kind == "outlet" and blank?(outlet_id) ->
        {:error, %{outlet_id: ["is required for an outlet conversation"]}}

      kind == "support" and not is_nil(outlet_id) ->
        {:error, %{outlet_id: ["must be empty for support"]}}

      true ->
        :ok
    end
  end

  defp blank?(v), do: not is_binary(v) or String.trim(v) == ""
end
