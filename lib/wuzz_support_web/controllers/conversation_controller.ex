defmodule WuzzSupportWeb.ConversationController do
  @moduledoc "History and conversation management; live traffic goes over the socket."
  use WuzzSupportWeb, :controller

  alias WuzzSupport.Auth.Identity
  alias WuzzSupport.Chat

  def index(conn, params) do
    conversations =
      Chat.list_conversations(conn.assigns.identity,
        status: params["status"],
        kind: params["kind"]
      )

    json(conn, %{data: Enum.map(conversations, &Chat.to_map/1)})
  end

  # Only customers start threads: `{"kind": "support"}` or
  # `{"kind": "outlet", "outlet_id": "12"}`.
  def create(conn, params) do
    who = conn.assigns.identity

    if Identity.admin?(who) or Identity.outlet_staff?(who) do
      forbidden(conn)
    else
      case Chat.open_conversation(who, params["kind"], params["outlet_id"]) do
        {:ok, c} ->
          conn |> put_status(:created) |> json(%{data: Chat.to_map(c)})

        {:error, errors} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: errors})
      end
    end
  end

  def messages(conn, %{"id" => id} = params) do
    with %{} = c <- Chat.get_conversation(id),
         true <- Chat.can_access?(conn.assigns.identity, c) do
      before =
        case DateTime.from_iso8601(params["before"] || "") do
          {:ok, dt, _} -> dt
          _ -> nil
        end

      json(conn, %{data: c |> Chat.list_messages(before) |> Enum.map(&Chat.to_map/1)})
    else
      _ -> not_found(conn)
    end
  end

  def close(conn, %{"id" => id}) do
    with %{} = c <- Chat.get_conversation(id),
         true <- Chat.can_access?(conn.assigns.identity, c),
         {:ok, c} <- Chat.close_conversation(c) do
      json(conn, %{data: Chat.to_map(c)})
    else
      _ -> not_found(conn)
    end
  end

  # STUN/TURN servers for a call. Credentials are short-lived and per user.
  def ice_servers(conn, _params) do
    json(conn, %{data: WuzzSupport.Calls.ice_servers(conn.assigns.identity)})
  end

  # 404 rather than 403 for threads the caller may not see, so ids don't leak.
  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "not found"})
  defp forbidden(conn), do: conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
end
