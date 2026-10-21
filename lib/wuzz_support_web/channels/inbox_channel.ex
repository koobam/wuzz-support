defmodule WuzzSupportWeb.InboxChannel do
  @moduledoc """
  Staff-side feed of conversation changes: `inbox:admin` for support admins,
  `inbox:outlet:<id>` for that outlet's staff. Receives
  `conversation_updated` whenever a thread opens or gets a new message.
  """
  use Phoenix.Channel

  alias WuzzSupport.Auth.Identity

  @impl true
  def join("inbox:admin", _params, socket) do
    if Identity.admin?(socket.assigns.identity), do: {:ok, socket}, else: denied()
  end

  def join("inbox:outlet:" <> outlet_id, _params, socket) do
    who = socket.assigns.identity

    if Identity.admin?(who) or outlet_id in Identity.outlet_ids(who),
      do: {:ok, socket},
      else: denied()
  end

  def join(_topic, _params, _socket), do: denied()

  defp denied, do: {:error, %{reason: "forbidden"}}
end
