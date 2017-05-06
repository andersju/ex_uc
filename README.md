# ExUc - Elixir Unit Converter

[![Build Status](https://circleci.com/gh/carturoch/ex_uc.svg?style=shield&circle-token=fd3d9870245619fd325e90c5cabfb70109eb139b)](https://circleci.com/gh/carturoch/ex_uc)

Converts values between units.

## Installation

From [Hex](https://hexdocs.pm/ex_uc), the package can be installed as:

  1. Add `ex_uc` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:ex_uc, "~> 1.0"}]
end
```

### Requirements

This package requires _Elixir **1.3+**_

## Usage

The quickest way is the function `convert`:
```elixir
iex>ExUc.convert("5 pounds", "oz")
"80.00 oz"
```
This is just a shortcut for the 3-steps pipeline:
```elixir
import ExUc

new_val = from("5 pounds")  # %ExUc.Value{unit: :lb, value: 5, kind: :mass}
|> to(:oz)                  # %ExUc.Value{unit: :oz, value: 80, kind: :mass}
|> as_string                # "80.00 oz"
```

The same unit can be identified by several aliases:
```elixir
convert("5 km", "miles") # "3.11 miles"
convert("5 kms", "mi") # "3.11 mi"
convert("5 kilometers", "mile") # "3.11 mile"
convert("5km", "mile") # "3.11 mile"
```

### Errors

Only two errors are returned when found, both as self descriptive **strings**:

  - `"undefined origin"`: Unit for the original value can't be parsed or found in any defined kind.
  - `"undetermined conversion"`: Conversion between the given units can't be determined.


## Configuration

The only two configurable variables are:

  - `precision` How many decimals will have the result when is converted into **string**
  - `allow_exact_results` When `true`, truncates decimal zeros in exact results.

Could be set as:
```elixir
config :ex_uc, precision: 2
config :ex_uc, allow_exact_results: false
```

### Units

Included are some of the most frequent units grouped by kinds:

  - Length: (`m`, `km`, `cm`, `mm`, `ft`, `in`, `yd`, `mi`, `ft_in`).
  - Mass: (`g`, `kg`, `mg`, `lb`, `oz`, `lb_oz`).
  - Time: (`μs`, `ms`, `s`, `min`, `h`, `d`).
  - Temperature: (`C`, `F`, `K`).
  - Speed: (`km/h`, `mph`, `m/s`, `kn`).
  - Pressure: (`Pa`,  `hPa`,  `kPa`,  `bar`,  `at`,  `atm`,  `mmHg`,  `psi`).
  - Memory: (`B`, `KB`, `MB`, `GB`, `TB`, `PB`, `EB`, `ZB`, `YB`, `b`, `Kb`, `Mb`, `Gb`, `Tb`, `Pb`, `Eb`, `Zb`, `Yb`, `KiB`, `MiB`, `GiB`, `TiB`, `PiB`, `EiB`, `ZiB`, `YiB`).

### Adding More Units

Kinds are really easy to extend. You don't need to add a conversion to every other existent unit in the _kind_ (though, of course you can). **ExUc** will find the shortest path in a _kind_ of units as a graph, using defined conversions.

Unit types (_kinds_) should be defined using configuration options for `:ex_uc` application. Each unit must have definitions for _units_ and _conversions_ (See some included examples at _config/units_ in this repository).

New or overridden definitions should follow this structure:

```elixir
use Mix.Config

config :ex_uc, :<KIND>_units,
  <UNIT>: ["alias 1", "alias 2", "alias N"], # List with every alias intended to relate to unit identified by UNIT

config :ex_uc, :<KIND>_conversions,
  <UNIT_A>_to_<UNIT_B>: 0.001,      # Multiplication factor
  <UNIT_C>_to_<UNIT_D>: &(&1 + 5)   # Conversion formula.
  <UNIT_X>_to_<UNIT_Y>: :special    # Atom referencing a special method.  
```

Which have two sections:

  - **Aliases**
    - Key as `<KIND>_units` where kind identifies the type of measurement, e.g: _length_, _temperature_, _pressure_, etc.
    - Each unit to support in the `kind` as a pair `unit:aliases` where **unit** is the most used unit and **aliases** is a list of strings (or a single one), one for each supported representation of the unit.
  - **Conversions**
    - Key as `<KIND_conversions>` using the same **kind** from the **alias** section.
    - Each conversion as a pair `key:conversion`, where **key** is an atom with the pattern `<UNIT_FROM>_to_<UNIT_TO>`, and **conversion** could be a _number_, or a _closure_, or an _atom_. Numeric conversions describe multiplication factors, and can be also used as `<B>_to_<A>: 1 / conversion` for a `<A>_to_<B>: factor` without explicit definition. When a factor is not enough, a _closure_ can be used as a simple formula. For special cases use an _atom_ to describe a function in module `Special`.

### Better Unit Conversions

**PRs** or **Issues** with new units or more accurate conversions are welcome.

## Documentation

Detailed documentation can be found at [hex docs](https://hexdocs.pm/ex_uc).

## Note

This project was inspired by the awesome [Ruby gem](https://github.com/olbrich/ruby-units) by _Kevin C. Olbrich, Ph.D._

## License

[MIT](https://github.com/carturoch/ex_uc/blob/master/License.md)
