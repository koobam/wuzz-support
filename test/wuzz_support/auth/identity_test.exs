defmodule WuzzSupport.Auth.IdentityTest do
  use ExUnit.Case, async: true

  alias WuzzSupport.Auth.Identity

  test "an admin is recognised by the admin role" do
    assert Identity.admin?(%Identity{id: "1", roles: ["admin"]})
    refute Identity.admin?(%Identity{id: "1", roles: ["outlet:3"]})
    refute Identity.admin?(%Identity{id: "1", roles: []})
  end

  test "outlet ids come from outlet:<id> roles" do
    identity = %Identity{id: "1", roles: ["outlet:3", "admin", "outlet:12"]}
    assert Identity.outlet_ids(identity) == ["3", "12"]
    assert Identity.outlet_staff?(identity)
  end

  test "an empty outlet id does not count" do
    identity = %Identity{id: "1", roles: ["outlet:"]}
    assert Identity.outlet_ids(identity) == []
    refute Identity.outlet_staff?(identity)
  end

  test "a customer has no roles" do
    refute Identity.outlet_staff?(%Identity{id: "1", roles: []})
  end
end
