defmodule Diet.Stepper do

  @moduledoc """
  Executes the reduction machine until it generates a terminating
  transition.

  Before performing any work, you need to initialize a stepper, passing
  it the module containing the reductions and a state that the
  reductions can use:

  ~~~ elixir
  stepper = Stepper.new(RunLengthEncode, nil)
  ~~~

  You then run the machine, passing in any parameters you like.
  Conventionally, you'll pass either an atom representing an event, or
  a tuple with an atom and some additional parameters.

  ~~~ elixir
  { result, updated_stepper } = Stepper.run(stepper, { :encode, "11123342111" }
  ~~~

  """

  alias Diet.History

  defstruct(
    module:       nil,
    model:        nil,
    history:      [],
    run_index:    0,
    step_index:   0)

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

  def clone(stepper, history) do
    { number, state } = hd(history)
    [ run, step ] =
      number
      |> to_string
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)
    
    %__MODULE__ {
      module: stepper.module,
      model:  state.new_model,
      history: history,
      run_index: run,
      step_index: step
    }
  end
  
  @doc """
  Run the reduction machine, passing the initial trigger. The machine
  will then return the result of reducing that. If the result
  represents the conclusion of the machine's work, it will return
  `{ :done, result, model }`. We extract the result and the updated
  model and return them in a tuple to the caller.
  """

  def run(stepper, trigger) do
    { result, stepper } =
    stepper
    |> History.push()
    |> run_step(trigger)
    |> after_step()

    stepper = History.pop(stepper)
    { result, stepper }
  end
 
  defp run_step(stepper, trigger) do
    step_result = stepper.module.step({ trigger, stepper.model })
    { _continue_or_done, result, model } = step_result
    stepper     = History.record(stepper, trigger, result, model)
    { stepper, step_result }
  end

  defp after_step({ stepper, { :continue, result, model }}) do
    run_step( %{ stepper | model: model }, result)
    |> after_step()
  end

  defp after_step({ stepper, { :done, result, model }}) do
    { result, %{ stepper | model: model } }
  end

end
