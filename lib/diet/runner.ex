defmodule Diet.Runner do

  @moduledoc """
  Executes the reduction machine until it generates a terminating
  transition.

  Before performing any work, you need to initialize a runner, passing
  it the module containing the reductions and a state that the
  reductions can use:

  ~~~ elixir
  runner = Runner.new(RunLengthEncode, nil)
  ~~~

  You then run the machine, passing in any parameters you like.
  Conventionally, you'll pass either an atom representing an event, or
  a tuple with an atom and some additional parameters.

  ~~~ elixir
  { result, updated_runner } = Runner.run(runner, { :encode, "11123342111" }
  ~~~

  """


  defstruct module: nil, current_step: nil, model: nil

  def new(module, model_params) do
    model_module = module.rm_model()
    model_data = if model_module do
      model_module.build(model_params)
    else
      model_params
    end

    %__MODULE__{
      module: module,
      model:  model_data,
    }
  end

  @doc """
  Run the reduction machine, passing the initial trigger. The machine
  will then return the result of reducing that. If the result
  represents the conclusion of the machine's work, it will return
  `{ :done, result, model }`. We extract the result and the updated
  model and return them in a tuple to the caller.
  """

  def run(runner, trigger) do
    run_step(runner, trigger)
    |> after_step(runner)
  end




  defp run_step(runner, result) do
    apply(runner.module, :step, [ { result, runner.model }  ])
  end

  defp after_step({ :continue, result, model }, runner) do
    run_step( %{ runner | model: model }, result)
    |> after_step(runner)
  end

  defp after_step({ :done, result, model }, runner) do
    { result, %{ runner | model: model } }
  end

  
end
