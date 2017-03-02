defmodule Diet.Mixfile do
  use Mix.Project

  @version "0.1.0"
  @deps    []

  @description """
  Diet is a DSL for writing your program logic as a sequence of trivial
  transformations. 

  For example, we could write FizzBuzz as

        defmodule Example.Fizzbuzz do

          use Diet.Transformations

          reductions do

            { :fizzbuzz, num }       -> { :fizzbuzz, num, rem(num, 3), rem(num, 5) }

            { :fizzbuzz, _,   0, 0 } -> "FizzBuzz"
            { :fizzbuzz, _,   0, _ } -> "Fizz"
            { :fizzbuzz, _,   _, 0 } -> "Buzz"
            { :fizzbuzz, num, _, _ } -> to_string(num)

          end
        end

  These transformations are executed by something called the Stepper.

  See https://github.com/pragdave/diet_examples for some example code, and
  https://www.youtube.com/watch?v=L1-amhlGk7c for a talk that contains
  examples of Diet in action.
  """
 
  # ============================================================

  @in_production Mix.env == :prod
  
  def project do
    [
      app:     :diet,
      version: @version,
      elixir:  "~> 1.5-dev",
      deps:    @deps,
      package: package(),
      description:     @description,
      build_embedded:  @in_production,
      start_permanent: @in_production,
    ]
  end

  def application do
    [
      extra_applications: [ :logger ]
    ]
  end

  defp package do
    [
      files: [
        "lib", "mix.exs", "README.md", "LICENSE.md"
      ],
      maintainers: [
        "Dave Thomas <dave@pragdave.me>"
      ],
      licenses: [
        "Apache 2 (see the file LICENSE.md for details)"
      ],
      links: %{
        "GitHub" => "https://github.com/pragdave/diet",
      }
    ]
  end  
end
