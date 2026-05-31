defmodule Server do
  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Server.listen() end}], strategy: :one_for_one)
  end

  def listen() do
    {:ok, socket} =
      :gen_udp.open(2053, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    loop(socket)
  end

  defp loop(socket) do
    case :gen_udp.recv(socket, 512) do
      {:ok, {address, port, data}} ->
        message = build_message(header())
        IO.inspect(data, label: "TEST as binaries")
        IO.inspect(data, binaries: :as_strings, label: "TEST as strings")

        response = message.header

        IO.inspect(response, label: "TS")
        :gen_udp.send(socket, address, port, response)
        loop(socket)

      {:error, reason} ->
        IO.puts("Error receiving data: #{inspect(reason)}")
    end
  end

  defp build_message(header) do
    %Message{header: header}
  end

  defp header,
    do: <<1234::16, 1::1, 0::4, 0::1, 0::1, 0::1, 0::1, 0::3, 0::4, 0::16, 0::16, 0::16, 0::16>>

  def main(_args) do
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_dns_server)
    Process.sleep(:infinity)
  end
end
