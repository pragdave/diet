defmodule Diet.History do
  
  def push(stepper) do
    %{ stepper | run_index: stepper.run_index + 1, step_index: 0 }
       
  end

  def pop(stepper) do
    stepper
  end

  def record(stepper, trigger, result, new_model) do
    entry = %{
      trigger:   trigger,
      old_model: stepper.model,
      new_model: new_model,
      result:    result
    }

    with step_no = stepper.step_index + 1,
         step = { :"#{stepper.run_index}.#{step_no}", entry },
    do: %{ stepper | history: [ step | stepper.history ], step_index: step_no}
  end
  
end
