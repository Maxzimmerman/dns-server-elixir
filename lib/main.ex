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
        IO.inspect(data, label: "TEST DATA")

        <<id::16, qr::1, opcode::4, aa::1, tc::1, rd::1, ra::1, z::3, rcode::4, ancount::16,
          nscount::16, arcount::16, rest::binary>> = data

        header_map = %{
          id: id,
          qr: qr,
          opcode: opcode,
          aa: aa,
          tc: tc,
          rd: rd,
          ra: ra,
          z: z,
          rcode: rcode,
          ancount: ancount,
          nscount: nscount,
          arcount: arcount
        }

        IO.inspect(header_map)

        IO.inspect(id, label: "TEST id")
        message = build_message(header(), question(), answer())

        response = message.header <> message.question <> message.answer

        IO.inspect(response, label: "TS")
        :gen_udp.send(socket, address, port, response)
        loop(socket)

      {:error, reason} ->
        IO.puts("Error receiving data: #{inspect(reason)}")
    end
  end

  defp build_message(header, question, answer) do
    %Message{header: header, question: question, answer: answer}
  end

  defp header,
    do: <<1234::16, 1::1, 0::4, 0::1, 0::1, 0::1, 0::1, 0::3, 0::4, 1::16, 1::16, 0::16, 0::16>>

  defp question,
    do: <<12, "codecrafters", 2, "io", 0, 1::16, 1::16>>

  defp answer,
    do: <<12, "codecrafters", 2, "io", 0, 1::16, 1::16, 60::32, 4::16, 1234::32>>

  def main(_args) do
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_dns_server)
    Process.sleep(:infinity)
  end
end
