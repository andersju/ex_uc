defmodule ExUc do
  @moduledoc """
  # Elixir Unit Converter

  Converts values with units within the same kind.

  It could be used as:
  ```elixir
  value = ExUc.from("5' 2\\"")
    |> ExUc.to(:m)
    |> ExUc.as_string
  ```
  Or:
  ```elixir
  import ExUc

  from("25C") |> to(:F) |> as_string # "77 F"
  ```

  Or simply:
  ```elixir
  "\#{ExUc.to("72F", :K)}" # "295.37 K"
  ```
  """

  alias ExUc.Value
  alias ExUc.Special

  @doc """
  Parses a string into a structured value. When is not possible to get
  a value from the given string, `nil` will be returned. This makes the
  process to fail by not being able to match a valid struct.

  Returns %ExUc.Value{}

  ## Parameters

    - str: String containing the value and unit to convert.

  ## Examples
  ```

  iex>ExUc.from("500 mg")
  %ExUc.Value{value: 500.0, unit: :mg, kind: :mass}

  iex>ExUc.from("5 alien")
  nil

  ```
  """
  def from(str) do
    {val, unit_str} = cond do
      Special.is_pounds_and_ounces?(str) -> Special.lb_oz_to_lb(str)
      Special.is_feet_and_inches?(str) -> Special.ft_in_to_ft(str)
      true -> Float.parse(str)
    end

    with unit <- unit_str |> String.trim |> String.to_atom,
      kind_str <- kind_of_unit(unit),
      _next when not is_nil(kind_str) <- kind_str,
      kind <- String.to_atom(kind_str),
    do: %Value{value: val, unit: unit, kind: kind}
  end

  @doc """
  Takes an structured value and using its kind converts it to the given unit.

  Returns %ExUc.Value{}

  ## Parameters

    - val: ExUc.Value to convert.
    - unit: Atom representing the unit to convert the `val` to.

  ## Examples
  ```
  iex> ExUc.to(%{value: 20, unit: :g, kind: :mass}, :mg)
  %ExUc.Value{value: 20000, unit: :mg, kind: :mass}

  iex> ExUc.to("15C", :K)
  %ExUc.Value{value: 288.15, unit: :K, kind: :temperature}

  # Errors:
  iex> ExUc.to(nil, :g)
  {:error, "undefined origin"}

  iex> ExUc.to("10kg", :xl)
  {:error, "undefined conversion"}

  ```
  """
  def to(val, _unit_to) when is_nil(val), do: {:error, "undefined origin"}
  def to(val, unit_to) when is_binary(val), do: to(from(val), unit_to)
  def to(val, unit_to) when is_map(val) do
    with %{unit: unit_from, value: value_from, kind: _} <- val,
      {:ok, factor} <- get_conversion(unit_from, unit_to),
      new_value <- apply_conversion(value_from, factor),
    do: %Value{value: new_value, unit: unit_to, kind: val.kind}
  end

  @doc """
  Converts an structured value into a string.

  ## Parameters

    - val: ExUc.Value to stringify.

  ## Examples
  ```

  iex> ExUc.as_string(%ExUc.Value{value: 10, unit: :m})
  "10.00 m"

  iex> ExUc.as_string({:error, "some error"})
  "some error"

  ```
  """
  def as_string({:error, msg}) when is_binary(msg), do: msg
  def as_string(val) do
    "#{val}"
  end

  @doc """
  Gets a map with every kind of unit defined in config.

  The result has a very traversable structure as:
  ```
  %{
    kind_of_unit: [
      alias_0: :main,
      alias_N: :main,
    ],
    ...
  }
  ```

  Returns List
  """
  def units do
    Application.get_all_env(:ex_uc)
    |> Enum.filter(fn {kind, _opts} -> Atom.to_string(kind) |> String.ends_with?("_units") end)
    |> Enum.map(fn {kind, units} ->
      units_map = units
      |> Enum.flat_map(fn {main, aliases} ->
        cond do
          is_list(aliases) -> Keyword.merge([{main, main}], for(alias <- aliases, do: {alias, main}))
          is_binary(aliases) -> [{main, main},{String.to_atom(aliases), main}]
          true -> [{main, main},{aliases, main}]
        end
      end)
      {kind, units_map}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Gets the kind of unit for ther given unit.

  ## Parameters

    - unit: Atom representing the unit to find the kind.

  ## Examples
  ```

  iex>ExUc.kind_of_unit(:kg)
  "mass"

  iex>ExUc.kind_of_unit(:meter)
  "length"

  ```
  """
  def kind_of_unit(unit) do
    kind_kw = units
    |> Enum.find(fn {_kind, units} -> units |> Keyword.has_key?(unit) end)

    case kind_kw do
      {kind_name, _units} -> kind_name
        |> Atom.to_string
        |> String.replace_suffix("_units", "")

      _ -> nil
    end
  end

  def get_key_unit(alias, kind) do
    kind_token = "#{kind}_units" |> String.to_atom
    with aliases <- Map.get(units, kind_token),
      main <- Keyword.get_values(aliases, alias) |> List.first,
    do: main
  end

  @doc """
  Gets the conversion factor for the units

  If can find inverse relation when the conversion is a factor.

  Returns Atom.t, Integer.t, Float.t

  ## Parameters

    - from: Atom representing the unit to convert from
    - to: Atom representing the unit to convert to

  ## Examples
  ```

  iex>ExUc.get_conversion(:g, :mg)
  {:ok, 1000}

  iex>ExUc.get_conversion(:g, :zz)
  {:error, "undefined conversion"}

  # This relation has not been defined but
  # the inverse is based on a factor, so is valid.
  iex>ExUc.get_conversion(:km, :m)
  {:ok, 1.0e3}

  ```
  """
  def get_conversion(from_alias, to_alias) do
    kind = kind_of_unit(from_alias)
    conversion_key = "#{kind}_conversions" |> String.to_atom

    {from, to} = {get_key_unit(from_alias, kind), to_alias}
    conversions = Application.get_env(:ex_uc, conversion_key) |> Enum.into(%{})
    regular_key = "#{from}_to_#{to}" |> String.to_atom
    inverted_key = "#{to}_to_#{from}" |> String.to_atom

    cond do
      Map.has_key?(conversions, regular_key) ->
        {:ok, Map.get(conversions, regular_key)}
      Map.has_key?(conversions, inverted_key) && is_number(Map.get(conversions, inverted_key)) ->
        {:ok, 1 / Map.get(conversions, inverted_key)}
      true -> {:error, "undefined conversion"}
    end
  end

  defp apply_conversion(val, factor) when is_number(factor), do: val * factor
  defp apply_conversion(val, formule) when is_function(formule), do: formule.(val)
  defp apply_conversion(val, method) when is_atom(method), do: apply(Special, method, [val])
end
