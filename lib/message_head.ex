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
      <<head.id::16, head.qr::1, head.opcode::4, head.aa::1, head.tc::1, head.rd::1, head.ra::1,
        head.z::3, head.rcode::4, head.ancount::16, head.nscount::16, head.arcount::16>>
end
