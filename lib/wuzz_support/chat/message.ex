defmodule WuzzSupport.Chat.Message do
  defstruct [:id, :conversation_id, :sender_id, :sender_role, :body, :inserted_at]

  @max_body 2000

  def from_doc(doc) do
    %__MODULE__{
      id: doc["_id"],
      conversation_id: doc["conversation_id"],
      sender_id: doc["sender_id"],
      sender_role: doc["sender_role"],
      body: doc["body"],
      inserted_at: doc["inserted_at"]
    }
  end

  @doc "Trims and validates a body: `{:ok, body}` or `:error`."
  def clean_body(body) when is_binary(body) do
    body = String.trim(body)
    if body != "" and String.length(body) <= @max_body, do: {:ok, body}, else: :error
  end

  def clean_body(_), do: :error
end
