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
        {questions, _} = parse_questions(rest, data, header.qdcount, [])
        question_bytes = questions |> Enum.map(&build_question/1) |> Enum.join()
        answer_bytes = questions |> Enum.map(&build_answer/1) |> Enum.join()
        message = build_message(header, question_bytes, answer_bytes, questions)

        response = MessageHead.to_binary_str(message.header) <> message.question <> message.answer

        IO.inspect(System.argv())

        if Enum.member?(Sytem.argv(), "--resolver") do
          IO.puts("to another server")
          :gen_udp.send(socket, address, port, response)
        end

        loop(socket)

      {:error, reason} ->
        IO.puts("Error receiving data: #{inspect(reason)}")
    end
  end

  def parse_labels(<<0, rest::binary>>, _packet, labels), do: {Enum.reverse(labels), rest}

  def parse_labels(<<0b11::2, offset::14, rest::binary>>, packet, labels) do
    <<_skip::binary-size(offset), at_offset::binary>> = packet
    {pointed_labels, _} = parse_labels(at_offset, packet, [])
    {Enum.reverse(labels) ++ pointed_labels, rest}
  end

  def parse_labels(<<length, label::binary-size(length), rest::binary>>, packet, labels) do
    parse_labels(rest, packet, [label | labels])
  end

  def build_question_block([], block), do: block <> <<0, 1::16, 1::16>>

  defp encode_name([]), do: <<0>>
  defp encode_name([label | rest]), do: <<byte_size(label), label::binary>> <> encode_name(rest)

  defp build_question(labels),
    do: encode_name(labels) <> <<1::16, 1::16>>

  defp build_answer(labels),
    do: encode_name(labels) <> <<1::16, 1::16, 60::32, 4::16, 8, 8, 8, 8>>

  defp parse_questions(rest, _packet, 0, acc), do: {Enum.reverse(acc), rest}

  defp parse_questions(rest, packet, n, acc) do
    {labels, after_name} = parse_labels(rest, packet, [])
    <<_type::16, _class::16, after_q::binary>> = after_name
    parse_questions(after_q, packet, n - 1, [labels | acc])
  end

  defp extract_header_bites_and_return_rest(data) do
    <<id::16, qr::1, opcode::4, aa::1, tc::1, rd::1, ra::1, z::3, rcode::4, qdcount::16,
      ancount::16, nscount::16, arcount::16, rest::binary>> = data

    # transfor header to answer type 
    header = %MessageHead{
      id: id,
      qr: qr,
      opcode: opcode,
      aa: aa,
      tc: tc,
      rd: rd,
      ra: ra,
      z: z,
      rcode: rcode,
      qdcount: qdcount,
      ancount: ancount,
      nscount: nscount,
      arcount: arcount
    }

    %{header: header, rest: rest}
  end

  defp build_message(%MessageHead{} = header, question, answer, questions) do
    response_header = %MessageHead{
      header
      | qr: 1,
        qdcount: length(questions),
        ancount: length(questions),
        rcode: if(header.opcode == 0, do: 0, else: 4)
    }

    %Message{header: response_header, question: question, answer: answer}
  end

  def header,
    do: <<1234::16, 1::1, 0::4, 0::1, 0::1, 0::1, 0::1, 0::3, 0::4, 1::16, 1::16, 0::16, 0::16>>

  def question,
    do: <<12, "codecrafters", 2, "io", 0, 1::16, 1::16>>

  def answer,
    do: <<12, "codecrafters", 2, "io", 0, 1::16, 1::16, 60::32, 4::16, 1234::32>>

  def main(_args) do
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_dns_server)
    Process.sleep(:infinity)
  end
end
