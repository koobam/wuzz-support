defmodule WuzzSupport.Chat do
  @moduledoc """
  Conversations between a customer and either support (admins) or an outlet,
  stored in MongoDB. Every access rule lives in `can_access?/2` and `visible/1`;
  the channel and controller layers only ask.
  """
  alias WuzzSupport.Auth.Identity
  alias WuzzSupport.Chat.{Conversation, Message}
  alias WuzzSupport.MongoIds

  @conversations "conversations"
  @messages "messages"
  @page 50

  ## Access

  def can_access?(%Identity{} = who, %Conversation{} = c) do
    Identity.admin?(who) or c.customer_id == who.id or
      (c.kind == "outlet" and c.outlet_id in Identity.outlet_ids(who))
  end

  @doc "Role a caller speaks as in `conversation`."
  def sender_role(%Identity{} = who, %Conversation{} = c) do
    cond do
      c.customer_id == who.id -> "customer"
      Identity.admin?(who) -> "admin"
      true -> "outlet"
    end
  end

  # Mongo filter selecting the conversations `who` may see.
  defp visible(%Identity{} = who) do
    if Identity.admin?(who) do
      %{}
    else
      mine = %{"customer_id" => who.id}

      case Identity.outlet_ids(who) do
        [] -> mine
        outlets -> %{"$or" => [mine, %{"kind" => "outlet", "outlet_id" => %{"$in" => outlets}}]}
      end
    end
  end

  ## Conversations

  def get_conversation(id) when is_binary(id) do
    :mongo |> Mongo.find_one(@conversations, %{"_id" => id}) |> Conversation.from_doc()
  end

  def get_conversation(_), do: nil

  def list_conversations(%Identity{} = who, opts \\ []) do
    filter =
      who
      |> visible()
      |> put_opt("status", opts[:status])
      |> put_opt("kind", opts[:kind])

    :mongo
    |> Mongo.find(@conversations, filter, sort: %{"last_message_at" => -1, "inserted_at" => -1}, limit: @page)
    |> Enum.map(&Conversation.from_doc/1)
  end

  defp put_opt(filter, _key, nil), do: filter
  defp put_opt(filter, key, value), do: Map.put(filter, key, value)

  @doc """
  Opens (or resumes) the caller's thread with support or an outlet. Only
  customers start conversations; staff answer them.
  """
  def open_conversation(%Identity{} = customer, kind, outlet_id \\ nil) do
    with :ok <- Conversation.validate(kind, outlet_id) do
      doc = %{
        "_id" => MongoIds.uuid(),
        "customer_id" => customer.id,
        "kind" => kind,
        "outlet_id" => outlet_id,
        "status" => "open",
        "last_message_at" => nil,
        "inserted_at" => now()
      }

      case Mongo.insert_one(:mongo, @conversations, doc) do
        {:ok, _} ->
          conversation = Conversation.from_doc(doc)
          notify_inbox(conversation)
          {:ok, conversation}

        {:error, %{write_errors: [%{"code" => 11000} | _]}} ->
          {:ok, find_open(customer.id, kind, outlet_id)}

        {:error, _} ->
          {:error, %{base: ["could not open the conversation"]}}
      end
    end
  end

  defp find_open(customer_id, kind, outlet_id) do
    filter = %{"customer_id" => customer_id, "kind" => kind, "outlet_id" => outlet_id, "status" => "open"}
    :mongo |> Mongo.find_one(@conversations, filter) |> Conversation.from_doc()
  end

  def close_conversation(%Conversation{id: id} = c) do
    case Mongo.update_one(:mongo, @conversations, %{"_id" => id}, %{"$set" => %{"status" => "closed"}}) do
      {:ok, _} -> {:ok, %{c | status: "closed"}}
      {:error, _} = error -> error
    end
  end

  ## Messages

  def list_messages(%Conversation{id: id}, before \\ nil) do
    filter =
      case before do
        nil -> %{"conversation_id" => id}
        dt -> %{"conversation_id" => id, "inserted_at" => %{"$lt" => dt}}
      end

    :mongo
    |> Mongo.find(@messages, filter, sort: %{"inserted_at" => -1}, limit: @page)
    |> Enum.map(&Message.from_doc/1)
    |> Enum.reverse()
  end

  def send_message(%Identity{} = who, %Conversation{status: "open"} = c, body) do
    with true <- can_access?(who, c) || {:error, :forbidden},
         {:ok, body} <- Message.clean_body(body) |> or_invalid() do
      sent_at = now()

      doc = %{
        "_id" => MongoIds.uuid(),
        "conversation_id" => c.id,
        "sender_id" => who.id,
        "sender_role" => sender_role(who, c),
        "body" => body,
        "inserted_at" => sent_at
      }

      # No multi-document transaction: a standalone Mongo has none. The message
      # is the source of truth; if bumping last_message_at fails, the thread just
      # sorts a little stale in the inbox until the next message.
      with {:ok, _} <- Mongo.insert_one(:mongo, @messages, doc),
           {:ok, _} <-
             Mongo.update_one(:mongo, @conversations, %{"_id" => c.id}, %{"$set" => %{"last_message_at" => sent_at}}) do
        notify_inbox(%{c | last_message_at: sent_at})
        {:ok, Message.from_doc(doc)}
      else
        _ -> {:error, :unavailable}
      end
    end
  end

  def send_message(_who, %Conversation{}, _body), do: {:error, :closed}

  defp or_invalid({:ok, _} = ok), do: ok
  defp or_invalid(:error), do: {:error, :invalid}

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:millisecond)

  ## Inbox fan-out: staff lists refresh when a thread appears or moves.

  def inbox_topics(%Conversation{kind: "outlet", outlet_id: o}), do: ["inbox:admin", "inbox:outlet:#{o}"]
  def inbox_topics(%Conversation{}), do: ["inbox:admin"]

  defp notify_inbox(%Conversation{} = c) do
    for topic <- inbox_topics(c) do
      WuzzSupportWeb.Endpoint.broadcast(topic, "conversation_updated", to_map(c))
    end

    :ok
  end

  ## Serialisation

  def to_map(%Conversation{} = c) do
    %{
      id: c.id,
      customer_id: c.customer_id,
      kind: c.kind,
      outlet_id: c.outlet_id,
      status: c.status,
      last_message_at: c.last_message_at,
      inserted_at: c.inserted_at
    }
  end

  def to_map(%Message{} = m) do
    %{
      id: m.id,
      conversation_id: m.conversation_id,
      sender_id: m.sender_id,
      sender_role: m.sender_role,
      body: m.body,
      inserted_at: m.inserted_at
    }
  end
end
