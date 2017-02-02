defmodule Diet.History do

  def push(stepper) do
    update_in(stepper.history, &[[] | &1])
  end

  def pop(stepper) do
    update_in(stepper.history,
      fn [ current | rest ] -> [ Enum.reverse(current) | rest] end)
  end

  def record(stepper, trigger, result, new_model) do
    entry = %{
      trigger:   trigger,
      old_model: stepper.model,
      new_model: new_model,
      result:    result
    }

    update_in(stepper.history,
      fn [ current | rest ] -> [[ entry | current ] | rest] end)
  end
end
