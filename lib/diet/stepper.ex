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


  defstruct module: nil, current_step: nil, model: nil, history: []

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

  def run(stepper, trigger) do
    stepper = update_in(stepper.history, &[  [ { :start, trigger, stepper.model } ] | &1 ])
    result = run_step(stepper, trigger) |> after_step()

  end




  defp run_step(stepper, trigger) do
    stepper = add_to_history(stepper, { :step, trigger, stepper.model })
    step_result = { _, result, model } = stepper.module.step({ trigger, stepper.model })
    stepper = add_to_history(stepper, { :step_end, trigger, result, model })
    { stepper, step_result }
  end

  defp after_step({ stepper, { :continue, result, model }}) do
    run_step( %{ stepper | model: model }, result)
    |> after_step()
  end

  defp after_step({ stepper, { :done, result, model }}) do
    { result, %{ stepper | model: model } }
  end

  # add the event to the current history entry (the list at the head of
  # the history list
  defp add_to_history(stepper = %{ history: [ current | rest ] }, event) do
    put_in(stepper.history, [ [ event | current ] | rest ])
  end

end
