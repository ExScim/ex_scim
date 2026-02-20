defmodule ExScimClient.Model.Operations.PatchOperationValue do
  @moduledoc """
  Value to apply (varies by op).
  """

  @derive JSON.Encoder
  defstruct []

  @type t :: %__MODULE__{}

  @doc false
  def decode(value) do
    value
  end
end
