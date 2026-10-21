defmodule WuzzSupportWeb.ConversationChannel do
  @moduledoc """
  One topic per conversation: `conversation:<uuid>`. Joining is authorised by
  `Chat.can_access?/2`; both sides of a thread receive `message` events as
  they happen.
  """
  use Phoenix.Channel

  alias WuzzSupport.{Calls, Chat}

  @impl true
  def join("conversation:" <> id, _params, socket) do
    with %{} = c <- Chat.get_conversation(id),
         true <- Chat.can_access?(socket.assigns.identity, c) do
      {:ok, assign(socket, :conversation, c)}
    else
      _ -> {:error, %{reason: "not_found"}}
    end
  end

  @impl true
  def handle_in("message", %{"body" => body}, socket) when is_binary(body) do
    # Re-read so a thread closed since join stops accepting messages.
    c = Chat.get_conversation(socket.assigns.conversation.id)

    case c && Chat.send_message(socket.assigns.identity, c, body) do
      {:ok, message} ->
        broadcast!(socket, "message", Chat.to_map(message))
        {:reply, :ok, socket}

      {:error, reason} when is_atom(reason) ->
        {:reply, {:error, %{reason: Atom.to_string(reason)}}, socket}

      nil ->
        {:reply, {:error, %{reason: "not_found"}}, socket}
    end
  end

  ## Calls (WebRTC signalling). The server keeps no call state: it relays between
  ## the participants already authorised to be on this topic, and tells staff who
  ## are not in the thread via their inbox.

  def handle_in("call:invite", params, socket) do
    c = Chat.get_conversation(socket.assigns.conversation.id)

    if c && c.status == "open" do
      who = socket.assigns.identity
      call_id = Calls.new_call_id()
      video = params["video"] == true

      broadcast_from!(socket, "call:incoming", %{
        call_id: call_id,
        from: %{id: who.id, name: who.name},
        video: video
      })

      for topic <- Chat.inbox_topics(c) do
        WuzzSupportWeb.Endpoint.broadcast(topic, "incoming_call", %{
          conversation_id: c.id,
          call_id: call_id,
          from: %{id: who.id, name: who.name},
          video: video
        })
      end

      {:reply, {:ok, %{call_id: call_id}}, socket}
    else
      {:reply, {:error, %{reason: "closed"}}, socket}
    end
  end

  def handle_in("call:" <> action, %{"call_id" => call_id} = payload, socket)
      when action in ["accept", "reject", "end", "signal"] do
    cond do
      not Calls.valid_call_id?(call_id) ->
        {:reply, {:error, %{reason: "bad_request"}}, socket}

      action == "signal" and not Calls.valid_signal?(payload) ->
        {:reply, {:error, %{reason: "bad_request"}}, socket}

      true ->
        who = socket.assigns.identity
        body = payload |> Map.take(["description", "candidate"]) |> Map.merge(%{"call_id" => call_id, "from" => who.id})
        event = if action == "signal", do: "call:signal", else: "call:#{past(action)}"
        broadcast_from!(socket, event, body)
        {:reply, :ok, socket}
    end
  end

  def handle_in("typing", _payload, socket) do
    identity = socket.assigns.identity
    broadcast_from!(socket, "typing", %{user_id: identity.id, name: identity.name})
    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket), do: {:reply, {:error, %{reason: "bad_request"}}, socket}

  defp past("accept"), do: "accepted"
  defp past("reject"), do: "rejected"
  defp past("end"), do: "ended"
end
