# Unit tests only: they start no Phoenix endpoint and need no MongoDB. JOSE and
# crypto are started by hand because `mix test` runs with --no-start (see mix.exs).
{:ok, _} = Application.ensure_all_started(:jose)
ExUnit.start()
