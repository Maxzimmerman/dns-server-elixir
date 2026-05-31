defmodule MessageHead do
  defstruct [:id, :qr, :opcode, :aa, :tc, :rd, :ra, :z, :rcode, :ancount, :nscount, :arcount]

  @type t :: %__MODULE__{
          id: binary(),
          qr: binary(),
          opcode: binary(),
          aa: binary(),
          tc: binary(),
          rd: binary(),
          ra: binary(),
          z: binary(),
          rcode: binary(),
          ancount: binary(),
          nscount: binary(),
          arcount: binary()
        }

  def to_struct(input_map) do
    %MessageHead{
      id: input_map.id,
      qr: input_map.qr,
      opcode: input_map.opcode,
      aa: input_map.aa,
      tc: input_map.tc,
      rd: input_map.rd,
      ra: input_map.ra,
      z: input_map.z,
      rcode: input_map.rcode,
      ancount: input_map.ancount,
      nscount: input_map.nscount,
      arcount: input_map.arcount
    }
  end

  def to_binary_str(%MessageHead{} = head),
    do:
      <<head.id::4, head.qr, head.opcode, head.aa, head.tc, head.rd, head.ra, head.z, head.rcode,
        head.ancount, head.nscount, head.arcount>>
end
