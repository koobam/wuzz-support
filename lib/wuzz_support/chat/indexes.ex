defmodule WuzzSupport.Chat.Indexes do
  @moduledoc """
  Creates the collections' indexes at boot. Idempotent, so every replica runs
  it; the Mongo pool connects asynchronously, so it retries until it can.
  """
  require Logger

  @conversations "conversations"
  @messages "messages"

  def ensure!(attempts \\ 30) do
    ttl = retention_seconds()

    with :ok <-
           Mongo.create_indexes(
             :mongo,
             @conversations,
             [
               [key: [kind: 1, status: 1, last_message_at: -1], name: "kind_status_last"],
               [key: [customer_id: 1], name: "customer"],
               [key: [outlet_id: 1, last_message_at: -1], name: "outlet_last"],
               # One open thread per customer per counterpart, so reopening the
               # chat resumes it. A missing outlet_id (support) counts as null,
               # so a customer has at most one open support thread too.
               [
                 key: [customer_id: 1, kind: 1, outlet_id: 1],
                 name: "one_open_per_counterpart",
                 unique: true,
                 partialFilterExpression: %{status: "open"}
               ]
             ] ++ conversation_ttl(ttl)
           ),
         :ok <-
           Mongo.create_indexes(
             :mongo,
             @messages,
             [
               [key: [conversation_id: 1, inserted_at: 1], name: "conversation_time"]
             ] ++ message_ttl(ttl)
           ) do
      :ok
    else
      error when attempts > 1 ->
        Logger.warning("mongo indexes not ready (#{inspect(error)}), retrying")
        Process.sleep(1_000)
        ensure!(attempts - 1)

      error ->
        raise "could not create mongo indexes: #{inspect(error)}"
    end
  end

  # Mongo deletes a document once its date field is older than this. Only closed
  # threads expire, so an open conversation never disappears under its customer.
  defp conversation_ttl(nil), do: []

  defp conversation_ttl(seconds) do
    [
      [
        key: [last_message_at: 1],
        name: "closed_ttl",
        expireAfterSeconds: seconds,
        partialFilterExpression: %{status: "closed"}
      ]
    ]
  end

  defp message_ttl(nil), do: []

  defp message_ttl(seconds),
    do: [[key: [inserted_at: 1], name: "message_ttl", expireAfterSeconds: seconds]]

  defp retention_seconds do
    case Application.get_env(:wuzz_support, :retention_days, 0) do
      days when is_integer(days) and days > 0 -> days * 86_400
      _ -> nil
    end
  end
end
