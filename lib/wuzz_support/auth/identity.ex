defmodule WuzzSupport.Auth.Identity do
  @moduledoc """
  Who the caller is, derived from the access token minted by wuzz-backend's
  user service. Roles ride in the JWT `roles` claim:

    * `"admin"`        – support staff, can see and answer every conversation
    * `"outlet:<id>"`  – staff of outlet `<id>`, limited to that outlet's threads
    * none of the above – a customer
  """
  defstruct [:id, :name, :roles]

  @type t :: %__MODULE__{id: String.t(), name: String.t() | nil, roles: [String.t()]}

  def admin?(%__MODULE__{roles: roles}), do: "admin" in roles

  def outlet_ids(%__MODULE__{roles: roles}) do
    for "outlet:" <> id <- roles, id != "", do: id
  end

  def outlet_staff?(identity), do: outlet_ids(identity) != []
end
