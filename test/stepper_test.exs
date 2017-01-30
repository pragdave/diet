defmodule StepperTest do
  use ExUnit.Case
  doctest Diet.Stepper

  alias Diet.Stepper

  test """
    uses the model param passed to new as the literal model if
    the transformer doesn't specify a model module
  """ do

    defmodule T do
      def rm_model, do: nil  # no model
    end

    stepper = Stepper.new(T, 123)

    assert stepper.model == 123
  end

  test """
    If specify a model in the transformer, then the stepper uses that model's
    `build` function to construct model data.
  """ do

    defmodule M do
      def build(param), do: param*param
    end

    defmodule T do
      def rm_model, do: M
    end

    stepper = Stepper.new(T, 9)

    assert stepper.model == 81
  end

  test """
    Runs a single step and then exits if there's no match for the next step.
  """ do

  end

end
