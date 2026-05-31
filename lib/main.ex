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
      {:ok, {address, port, data} = request} ->
        IO.inspect(request, label: "TST")
        IO.inspect(address, label: "Address")
        IO.inspect(port, label: "PORT")
        IO.inspect(data, label: "DATA")

        header =
          <<1234::16, 1::1, 0::4, 0::1, 0::1, 0::1, 0::1, 0::3, 0::4, 0::16, 0::16, 0::16, 0::16>>

        message = %Message{header: header}
        IO.inspect(message, label: "message")

        response =
          <<1234::16, 1::1, 0::4, 0::1, 0::1, 0::1, 0::1, 0::3, 0::4, 0::16, 0::16, 0::16, 0::16>>

        IO.inspect(response, label: "TS")
        :gen_udp.send(socket, address, port, response)
        loop(socket)

      {:error, reason} ->
        IO.puts("Error receiving data: #{inspect(reason)}")
    end
  end

  def main(_args) do
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_dns_server)
    Process.sleep(:infinity)
  end
end
