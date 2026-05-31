defmodule MessageHead do
  defstruct [
    :id,
    :qr,
    :opcode,
    :aa,
    :tc,
    :rd,
    :ra,
    :z,
    :rcode,
    :qdcount,
    :ancount,
    :nscount,
    :arcount
  ]

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
          qdcount: binary(),
          ancount: binary(),
          nscount: binary(),
          arcount: binary()
        }

  def to_binary_str(%MessageHead{} = head),
    do:
      <<head.id::16, head.qr::1, head.opcode::4, head.aa::1, head.tc::1, head.rd::1, head.ra::1,
        head.z::3, head.rcode::4, head.qdcount::16, head.ancount::16, head.nscount::16,
        head.arcount::16>>
end
