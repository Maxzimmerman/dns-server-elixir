defmodule Message do
  defstruct [:header, :question, :answer, :authority, :additional_space]

  @type t :: %__MODULE__{header: MessageHead.t()}
end
