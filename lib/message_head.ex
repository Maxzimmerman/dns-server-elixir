defmodule MessageHead do
  defstruct [:id, :qr, :opcode, :aa, :tc, :rd, :ra, :z, :rcode, :acount, :nscount, :arcount]

  def to_struct(input_map) do
    %MessageHead{
      id: input_map["id"],
      qr: input_map["qr"],
      opcode: input_map["opcode"],
      aa: input_map["aa"],
      tc: input_map["aa"],
      rd: input_map["rd"],
      ra: input_map["ra"],
      z: input_map[""],
      rcode: input_map["rcode"],
      acount: input_map["account"],
      nscount: input_map["nscount"],
      arcount: input_map["arcount"]
    }
  end
end
