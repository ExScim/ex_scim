defmodule ExScim.Parser.Path do
  @moduledoc false

  import NimbleParsec

  # --------------------------
  # Helper reducer functions
  # --------------------------

  def reduce_attr_path([raw]) do
    case String.split(raw, ":", trim: true) do
      parts when length(parts) > 1 ->
        schema = Enum.slice(parts, 0..-2//1) |> Enum.join(":")
        attr = List.last(parts)
        %{schema: schema, attribute: attr}

      _ ->
        %{schema: nil, attribute: raw}
    end
  end

  def reduce_attr_with_filter([base, filter]), do: Map.put(base, :filter, filter)
  def reduce_attr_with_filter([base]), do: base

  def reduce_filter_exp([attr, op, val]) do
    %{attr: attr, op: op, value: val}
  end

  def reduce_final_path([base, sub]) do
    Map.put(base, :sub, sub)
  end

  def reduce_final_path([base]), do: base

  # --------------------------
  # Combinators
  # --------------------------

  defcombinatorp(
    :attr_path,
    ascii_string([?a..?z, ?A..?Z, ?0..?9, ?:, ?., ?_, ?-], min: 1)
    |> reduce({__MODULE__, :reduce_attr_path, []})
  )

  defcombinatorp(
    :attr_name,
    ascii_string([?a..?z, ?A..?Z], 1)
    |> repeat(ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], 1))
    |> reduce({List, :to_string, []})
  )

  defcombinatorp(
    :filter_exp,
    utf8_string([not: ?]], min: 1)
    |> reduce({List, :to_string, []})
  )

  defcombinatorp(
    :attr_exp,
    parsec(:attr_path)
    |> optional(
      ignore(string("["))
      |> concat(parsec(:filter_exp))
      |> ignore(string("]"))
    )
    |> reduce({__MODULE__, :reduce_attr_with_filter, []})
  )

  path =
    parsec(:attr_exp)
    |> optional(
      ignore(string("."))
      |> concat(parsec(:attr_name))
    )
    |> reduce({__MODULE__, :reduce_final_path, []})
    |> eos()

  # parsec:ExScim.Parser.Path
  defparsec(:path, path)
  # parsec:ExScim.Parser.Path
end
