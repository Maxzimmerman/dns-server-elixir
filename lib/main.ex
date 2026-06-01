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
        %{header: header, rest: rest} = extract_header_bites_and_return_rest(data)
        IO.inspect(rest, label: "Test rest")
        {labels, _rest} = parse_labels(rest, [])
        message = build_message(header, question(), answer())
        IO.inspect(labels, label: "TEST LABELS")

        response = MessageHead.to_binary_str(message.header) <> message.question <> message.answer

        :gen_udp.send(socket, address, port, response)
        loop(socket)

      {:error, reason} ->
        IO.puts("Error receiving data: #{inspect(reason)}")
    end
  end

  def parse_labels(<<0, rest::binary>>, labels), do: {Enum.reverse(labels), rest}

  def parse_labels(<<length::8, label::binary-size(length), rest::binary>>, labels) do
    parse_labels(rest, [label | labels])
  end

  defp extract_header_bites_and_return_rest(data) do
    <<id::16, qr::1, opcode::4, aa::1, tc::1, rd::1, ra::1, z::3, _rcode::4, qdcount::16,
      _ancount::16, nscount::16, arcount::16, rest::binary>> = data

    # transfor header to answer type 
    header = %MessageHead{
      id: id,
      qr: 1,
      opcode: opcode,
      aa: aa,
      tc: tc,
      rd: rd,
      ra: ra,
      z: z,
      rcode: if(opcode == 0, do: 0, else: 4),
      qdcount: 1,
      ancount: 1,
      nscount: nscount,
      arcount: arcount
    }

    %{header: header, rest: rest}
  end

  defp build_message(%MessageHead{} = header, question, answer) do
    %Message{header: header, question: question, answer: answer}
  end

  def header,
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
