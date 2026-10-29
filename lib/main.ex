defmodule Server do
  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Client.listen() end}], strategy: :one_for_one)
  end
end
