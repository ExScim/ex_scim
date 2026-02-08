defmodule ExScimClient.Filter do
  @moduledoc """
  DSL for building filter expressions.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.equals("userName", "jdoe")
      iex> ExScimClient.Filter.build(filter)
      ~S|userName eq "jdoe"|

      iex> filter1 = ExScimClient.Filter.new() |> ExScimClient.Filter.equals("active", "true")
      iex> filter2 = ExScimClient.Filter.new() |> ExScimClient.Filter.starts_with("userName", "j")
      iex> combined = ExScimClient.Filter.and1(filter1, filter2)
      iex> ExScimClient.Filter.build(combined)
      ~S|(active eq "true") and (userName sw "j")|

  """

  defstruct [:expr]

  @type t :: %__MODULE__{
          expr: term() | nil
        }

  @doc """
  Creates a new empty filter.

  ## Examples

      iex> %ExScimClient.Filter{expr: nil} = ExScimClient.Filter.new()

  """
  @spec new() :: %__MODULE__{}
  def new, do: %__MODULE__{expr: nil}

  @doc """
  Builds the filter string from the filter struct.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.equals("active", "true")
      iex> ExScimClient.Filter.build(filter)
      ~S|active eq "true"|

  """
  @spec build(%__MODULE__{}) :: String.t()
  def build(%__MODULE__{expr: expression}), do: render(expression)

  # Comparison operator

  @doc """
  Adds an equals comparison to the filter.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.equals("active", "true")
      iex> ExScimClient.Filter.build(filter)
      ~S|active eq "true"|

  """
  @spec equals(%__MODULE__{}, String.t(), String.t()) :: %__MODULE__{}
  def equals(filter, attribute, value), do: put_expression(filter, {:eq, attribute, value})

  @doc """
  Adds a not-equal comparison to the filter.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.not_equal("active", "false")
      iex> ExScimClient.Filter.build(filter)
      ~S|active ne "false"|

  """
  @spec not_equal(%__MODULE__{}, String.t(), String.t()) :: %__MODULE__{}
  def not_equal(filter, attribute, value), do: put_expression(filter, {:ne, attribute, value})
  @doc """
  Adds a contains comparison to the filter.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.contains("emails.value", "example")
      iex> ExScimClient.Filter.build(filter)
      ~S|emails.value co "example"|

  """
  @spec contains(%__MODULE__{}, String.t(), String.t()) :: %__MODULE__{}
  def contains(filter, attribute, value), do: put_expression(filter, {:co, attribute, value})
  @doc """
  Adds a starts-with comparison to the filter.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.starts_with("userName", "admin")
      iex> ExScimClient.Filter.build(filter)
      ~S|userName sw "admin"|

  """
  @spec starts_with(%__MODULE__{}, String.t(), String.t()) :: %__MODULE__{}
  def starts_with(filter, attribute, value), do: put_expression(filter, {:sw, attribute, value})

  @doc """
  Adds an ends-with comparison to the filter.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.ends_with("emails.value", "example.com")
      iex> ExScimClient.Filter.build(filter)
      ~S|emails.value ew "example.com"|

  """
  @spec ends_with(%__MODULE__{}, String.t(), String.t()) :: %__MODULE__{}
  def ends_with(filter, attribute, value), do: put_expression(filter, {:ew, attribute, value})

  @doc """
  Adds a greater-than comparison to the filter.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.greater_than("meta.lastModified", "2023-01-01T00:00:00Z")
      iex> ExScimClient.Filter.build(filter)
      ~S|meta.lastModified gt "2023-01-01T00:00:00Z"|

  """
  @spec greater_than(%__MODULE__{}, String.t(), String.t()) :: %__MODULE__{}
  def greater_than(filter, attribute, value), do: put_expression(filter, {:gt, attribute, value})

  @doc """
  Adds a greater-than-or-equal comparison to the filter.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.greater_or_equal("meta.version", "2")
      iex> ExScimClient.Filter.build(filter)
      ~S|meta.version ge "2"|

  """
  @spec greater_or_equal(%__MODULE__{}, String.t(), String.t()) :: %__MODULE__{}
  def greater_or_equal(filter, attribute, value),
    do: put_expression(filter, {:ge, attribute, value})

  @doc """
  Adds a less-than comparison to the filter.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.less_than("meta.version", "5")
      iex> ExScimClient.Filter.build(filter)
      ~S|meta.version lt "5"|

  """
  @spec less_than(%__MODULE__{}, String.t(), String.t()) :: %__MODULE__{}
  def less_than(filter, attribute, value), do: put_expression(filter, {:lt, attribute, value})

  @doc """
  Adds a less-than-or-equal comparison to the filter.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.less_or_equal("meta.version", "10")
      iex> ExScimClient.Filter.build(filter)
      ~S|meta.version le "10"|

  """
  @spec less_or_equal(%__MODULE__{}, String.t(), String.t()) :: %__MODULE__{}
  def less_or_equal(filter, attribute, value), do: put_expression(filter, {:le, attribute, value})

  @doc """
  Adds a present comparison to the filter.

  ## Examples

      iex> filter = ExScimClient.Filter.new() |> ExScimClient.Filter.present("emails", nil)
      iex> ExScimClient.Filter.build(filter)
      "emails pr"

  """
  @spec present(%__MODULE__{}, String.t(), any()) :: %__MODULE__{}
  def present(filter, attribute, _value), do: put_expression(filter, {:pr, attribute, nil})

  # Logical operator

  @doc """
  Combines two filters with an AND operator.

  ## Examples

      iex> filter1 = ExScimClient.Filter.new() |> ExScimClient.Filter.equals("active", "true")
      iex> filter2 = ExScimClient.Filter.new() |> ExScimClient.Filter.starts_with("userName", "admin")
      iex> combined = ExScimClient.Filter.and1(filter1, filter2)
      iex> ExScimClient.Filter.build(combined)
      ~S|(active eq "true") and (userName sw "admin")|

  """
  @spec and1(%__MODULE__{}, %__MODULE__{}) :: %__MODULE__{}
  def and1(filter1, filter2), do: combine_expressions(:and, filter1, filter2)

  @doc """
  Combines two filters with a NOT operator.

  ## Examples

      iex> filter1 = ExScimClient.Filter.new() |> ExScimClient.Filter.equals("active", "true")
      iex> filter2 = ExScimClient.Filter.new() |> ExScimClient.Filter.equals("userType", "Employee")
      iex> combined = ExScimClient.Filter.not1(filter1, filter2)
      iex> ExScimClient.Filter.build(combined)
      ~S|(active eq "true") not (userType eq "Employee")|

  """
  @spec not1(%__MODULE__{}, %__MODULE__{}) :: %__MODULE__{}
  def not1(filter1, filter2), do: combine_expressions(:not, filter1, filter2)
  @doc """
  Combines two filters with an OR operator.

  ## Examples

      iex> filter1 = ExScimClient.Filter.new() |> ExScimClient.Filter.equals("userType", "Employee")
      iex> filter2 = ExScimClient.Filter.new() |> ExScimClient.Filter.equals("userType", "Contractor")
      iex> combined = ExScimClient.Filter.or1(filter1, filter2)
      iex> ExScimClient.Filter.build(combined)
      ~S|(userType eq "Employee") or (userType eq "Contractor")|

  """
  @spec or1(%__MODULE__{}, %__MODULE__{}) :: %__MODULE__{}
  def or1(filter1, filter2), do: combine_expressions(:or, filter1, filter2)

  # AST

  defp put_expression(%__MODULE__{expr: nil} = _filter, expression) do
    %__MODULE__{expr: expression}
  end

  defp put_expression(%__MODULE__{expr: _} = filter, expression) do
    %__MODULE__{filter | expr: expression}
  end

  defp combine_expressions(op, %__MODULE__{expr: expr1}, %__MODULE__{expr: expr2}) do
    %__MODULE__{expr: {op, expr1, expr2}}
  end

  # Render filter string

  defp render(nil), do: ""
  defp render({:eq, attribute, value}), do: "#{attribute} eq \"#{value}\""
  defp render({:ne, attribute, value}), do: "#{attribute} ne \"#{value}\""
  defp render({:co, attribute, value}), do: "#{attribute} co \"#{value}\""
  defp render({:sw, attribute, value}), do: "#{attribute} sw \"#{value}\""
  defp render({:ew, attribute, value}), do: "#{attribute} ew \"#{value}\""
  defp render({:gt, attribute, value}), do: "#{attribute} gt \"#{value}\""
  defp render({:ge, attribute, value}), do: "#{attribute} ge \"#{value}\""
  defp render({:lt, attribute, value}), do: "#{attribute} lt \"#{value}\""
  defp render({:le, attribute, value}), do: "#{attribute} le \"#{value}\""
  defp render({:pr, attribute, nil}), do: "#{attribute} pr"

  defp render({:and, expr1, expr2}), do: "(#{render(expr1)}) and (#{render(expr2)})"
  defp render({:not, expr1, expr2}), do: "(#{render(expr1)}) not (#{render(expr2)})"
  defp render({:or, expr1, expr2}), do: "(#{render(expr1)}) or (#{render(expr2)})"
end
