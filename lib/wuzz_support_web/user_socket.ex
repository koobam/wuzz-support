defmodule WuzzSupportWeb.UserSocket do
  use Phoenix.Socket

  alias WuzzSupport.Auth.Token

  channel "conversation:*", WuzzSupportWeb.ConversationChannel
  channel "inbox:*", WuzzSupportWeb.InboxChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Token.verify(token) do
      {:ok, identity} -> {:ok, assign(socket, :identity, identity)}
      :error -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.identity.id}"
end
