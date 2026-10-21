defmodule WuzzSupport.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Mongo, Application.fetch_env!(:wuzz_support, :mongo)},
      {Task, &WuzzSupport.Chat.Indexes.ensure!/0},
      {Phoenix.PubSub, name: WuzzSupport.PubSub},
      WuzzSupportWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: WuzzSupport.Supervisor)
  end
end
