defmodule ExScim.Parser.Filter do
  @moduledoc false
  import NimbleParsec
  import ExScim.Parser.Lexical

  # --------------------------
  # Helper reducer functions
  # --------------------------

  def to_op(op), do: String.downcase(op) |> String.to_atom()

  def to_comp_ast([attr, op, val]), do: {to_op(op), attr, val}
  def to_present_ast(attr), do: {:pr, attr}
  def to_not_ast(expr), do: {:not, expr}

  def to_comp_ast_wrapped([{_, attr}, {_, op}, {_, val}]) do
    {to_op(op), attr, val}
  end

  def reduce_logical_chain([head | rest]) do
    Enum.chunk_every(rest, 2)
    |> Enum.reduce(head, fn [op, right], acc -> {op, acc, right} end)
  end

  def join_path([first | rest]), do: Enum.join([first | rest], ".")

  def to_attribute_filter_ast([target | filter]), do: {target, filter}

  # --------------------------
  # Combinators
  # --------------------------

  defcombinatorp(
    :compare_op,
    choice(
      Enum.map(
        ~w(eq ne co sw ew gt lt ge le Eq Ne Co Sw Ew Gt Lt Ge Le eQ nE cO sW eW gT lT gE lE EQ NE CO SW EW GT LT GE LE),
        &string/1
      )
    )
  )

  defcombinatorp(
    :attr_char,
    ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?:, ?/])
  )

  defcombinatorp(
    :attr_name,
    ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?:, ?/], min: 1)
  )

  defcombinatorp(
    :attr_path,
    parsec(:attr_name)
    |> repeat(
      ignore(string("."))
      |> concat(parsec(:attr_name))
    )
    |> reduce({__MODULE__, :join_path, []})
  )

  defcombinatorp(
    :filtered_attr_expr,
    parsec(:attr_path)
    |> ignore(string("["))
    |> concat(parsec(:val_filter))
    |> ignore(string("]"))
    |> reduce({__MODULE__, :to_attribute_filter_ast, []})
  )

  defcombinatorp(
    :attr_exp,
    parsec(:attr_path)
    |> optional(
      ignore(string("["))
      |> concat(parsec(:val_filter))
      |> ignore(string("]"))
    )
  )

  defcombinatorp(
    :logical_op,
    ignore(wsp())
    |> choice([
      string("and"),
      string("And"),
      string("aNd"),
      string("anD"),
      string("ANd"),
      string("aND"),
      string("AnD"),
      string("AND"),
      string("or"),
      string("Or"),
      string("oR"),
      string("OR")
    ])
    |> map({__MODULE__, :to_op, []})
    |> ignore(wsp())
  )

  defcombinatorp(
    :comp_exp,
    parsec(:attr_exp)
    |> map({List, :wrap, []})
    |> ignore(wsp())
    |> concat(parsec(:compare_op) |> map({List, :wrap, []}))
    |> ignore(wsp())
    |> concat(comp_value() |> map({List, :wrap, []}))
    |> reduce({Enum, :concat, []})
    |> map({__MODULE__, :to_comp_ast, []})
  )

  defcombinatorp(
    :present_exp,
    parsec(:attr_exp)
    |> ignore(wsp())
    |> ignore(choice([string("pr"), string("Pr"), string("pR"), string("PR")]))
    |> map({__MODULE__, :to_present_ast, []})
  )

  defcombinatorp(
    :not_exp,
    ignore(
      choice([
        string("not"),
        string("Not"),
        string("nOt"),
        string("noT"),
        string("NOt"),
        string("nOT"),
        string("NoT"),
        string("NOT")
      ])
    )
    |> ignore(wsp())
    |> ignore(string("("))
    |> concat(parsec(:val_filter))
    |> ignore(string(")"))
    |> map({__MODULE__, :to_not_ast, []})
  )

  defcombinatorp(
    :paren_exp,
    ignore(string("("))
    |> concat(parsec(:val_filter))
    |> ignore(string(")"))
  )

  # primary_expr ::= basic atomic expressions
  defcombinatorp(
    :primary_expr,
    choice([
      parsec(:filtered_attr_expr),
      parsec(:comp_exp),
      parsec(:present_exp),
      parsec(:not_exp),
      parsec(:paren_exp)
    ])
  )

  # and_expr ::= primary_expr ("and" primary_expr)*
  defcombinatorp(
    :and_expr,
    parsec(:primary_expr)
    |> repeat(parsec(:logical_op) |> concat(parsec(:primary_expr)))
    |> reduce({__MODULE__, :reduce_logical_chain, []})
  )

  # or_expr ::= and_expr ("or" and_expr)*
  defcombinatorp(
    :or_expr,
    parsec(:and_expr)
    |> repeat(parsec(:logical_op) |> concat(parsec(:and_expr)))
    |> reduce({__MODULE__, :reduce_logical_chain, []})
  )

  defcombinatorp(:val_filter, parsec(:or_expr))

  # parsec:ExScim.Parser.Filter
  defparsec(:filter, parsec(:val_filter) |> eos())
  # parsec:ExScim.Parser.Filter
end
