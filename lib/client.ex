defmodule Client do
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

        answer_bytes =
          case resolver() do
            nil ->
              questions |> Enum.map(&build_answer/1) |> Enum.join()

            target ->
              questions |> Enum.map(&forward(&1, header, socket, target)) |> Enum.join()
          end

        question_bytes = questions |> Enum.map(&build_question/1) |> Enum.join()
        message = build_message(header, question_bytes, answer_bytes, questions)
        response = MessageHead.to_binary_str(message.header) <> message.question <> message.answer

        IO.inspect(data, label: "input data")
        IO.inspect(header, label: "input header")
        IO.inspect(resolver(), label: "Resolver")

        :gen_udp.send(socket, address, port, response)
        loop(socket)

      {:error, reason} ->
        IO.puts("Error receiving data: #{inspect(reason)}")
    end
  end

  defp resolver do
    case System.argv() do
      ["--resolver", addr] ->
        [ip_str, port_str] = String.split(addr, ":")

        ip =
          ip_str
          |> String.split(".")
          |> Enum.map(&String.to_integer/1)
          |> List.to_tuple()

        {ip, String.to_integer(port_str)}

      _ ->
        nil
    end
  end

  defp forward(labels, client_header, socket, {resolver_ip, resolver_port}) do
    query_header = %MessageHead{
      client_header
      | qr: 0,
        qdcount: 1,
        ancount: 0,
        nscount: 0,
        arcount: 0
    }

    query = MessageHead.to_binary_str(query_header) <> build_question(labels)
    :ok = :gen_udp.send(socket, resolver_ip, resolver_port, query)
    {:ok, {_, _, reply}} = :gen_udp.recv(socket, 512)
    extract_answer_bytes(reply)
  end

  defp extract_answer_bytes(reply) do
    <<_id::16, _qr::1, _opcode::4, _aa::1, _tc::1, _rd::1, _ra::1, _z::3, _rcode::4, qdcount::16,
      ancount::16, _nscount::16, _arcount::16, after_header::binary>> = reply

    after_questions = skip_questions(after_header, reply, qdcount)
    take_answers(after_questions, reply, ancount, <<>>)
  end

  defp skip_questions(rest, _packet, 0), do: rest

  defp skip_questions(rest, packet, n) do
    {_labels, after_name} = parse_labels(rest, packet, [])
    <<_type::16, _class::16, after_q::binary>> = after_name
    skip_questions(after_q, packet, n - 1)
  end

  defp take_answers(_rest, _packet, 0, acc), do: acc

  defp take_answers(rest, packet, n, acc) do
    {labels, after_name} = parse_labels(rest, packet, [])

    <<type::16, class::16, ttl::32, rdlength::16, rdata::binary-size(rdlength), after_a::binary>> =
      after_name

    encoded = encode_name(labels) <> <<type::16, class::16, ttl::32, rdlength::16, rdata::binary>>
    take_answers(after_a, packet, n - 1, acc <> encoded)
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
end
