defmodule Diet.Debug do

  def on(stepper) do
    name = stepper.module |> to_string |> String.trim_leading("Elixir.")
    IO.puts "\nDiet debugger looking at #{name}\n"
    IO.puts "h for help\n"

    stepper
    |> build_state(name)
    |> interact
  end

  defp build_state(stepper, name) do
    %{
      name:    name,
      steppers: %{ 0 => stepper },
      current:  0,
    }
  end

  defp interact(state) do
    res = IO.gets "#{state.name}[#{state.current}]> "
    handle(res, state)
  end

  defp handle({:error, reason}, _), do: IO.inspect(reason)
  defp handle(:eof, _), do: IO.puts("done")

  defp handle(other, state) do
    [ cmd | args ] =
    other
    |> String.trim
    |> String.downcase
    |> String.split

    command(cmd, Enum.join(args, " "), state)
  end

  ###################
  # c [ <step id> ] #
  ###################
  
  defp command("c", "", state) do
    command("c", [ hd(stepper(state).history).number ], state)
  end

  defp command("c", number, state) do
    new_history = stepper(state).history |> rollback_to(String.to_atom(number))
    new_stepper = Diet.Stepper.clone(stepper(state), new_history)
    current_max = (state.steppers |> Map.keys |> Enum.max) + 1
    
    put_in(state.steppers[current_max], new_stepper)
    |> Map.put(:current, current_max)
    |> interact
  end

  ####################################
  # clones   — show list of clones   #
  ####################################

  defp command("clones", _, state) do
    IO.puts "\n  #\tin state"
    IO.puts "  --\t--------\n"
    
    state.steppers
    |> Map.keys
    |> Enum.sort
    |> Enum.each(&show_clone(state, &1))
    interact(state)
  end

  #################################
  # switch n  — switch to clone n #
  #################################

  defp command("switch", clone, state) do
    clone = String.to_integer(clone)
    state = %{ state | current: clone }
    history = stepper(state).history
    step = most_recent_step(history)
    show_step(history, step)
    interact(state)
  end
  
  #######################
  # t   — trace history #
  #######################
  
  defp command("t", _, state) do
    stepper(state).history
    |> Enum.reverse
    |> dump_history

    interact(state)
  end

  ####################
  # h    — give help #
  ####################
  
  defp command("?", x, state), do: command("h", x, state)
  defp command("h", _, state) do
    IO.puts """

    t         – show execution trace
    n.n       – show details of step n.n
    r «trigger args»
              – run the stepper using the given trigger

    c [n.n]   – clone the current execution at the given step (or the current step
                if n.n is omitted
    clones    — list all clones
    switch n  — switch to clone #n
   
    q         – quit
    """
    interact(state)
  end

  ##############################
  # r <args>   — run a stepper #
  ##############################
  
  defp command("r", args, state) do
    args = if String.starts_with?(args, ":") && String.contains?(args, " ") do
      String.replace(args, " ", ", ", global: false)
    else
      args
    end

    args = if String.contains?(args, ",") && !String.starts_with?(args, "{") do
      "{ #{args} }"
    else
      args
    end

    try do
      {arg_val, _} = Code.eval_string(args)
      { result, stepper } = Diet.Stepper.run(stepper(state), arg_val)
      IO.puts "\nResult: #{inspect result, pretty: true}"
      put_in(state.steppers[state.current], stepper)
      |> interact
    rescue
      e in [ CompileError, SyntaxError ] ->
        IO.puts "error: #{e.description}\n"
        interact(state)
    end
  end

  ##############
  # q   — quit #
  ##############
  
  defp command("q", _, _state) do
    IO.puts "done\n"
  end

  defp command("", _, state) do
    interact(state)
  end


  ###########################
  # r.s   — display <r>.<s> #
  ###########################

  defp command(other, args, state) do
    case Regex.run(~r{^\d+\.\d+$}, other) do

      [step_id] ->
        show_step(stepper(state).history, step_id)

      _ ->
        IO.puts "Unknown command #{inspect other} #{inspect args}"
    end

    interact(state)
  end

  defp most_recent_step(history) do
    hd(history) |> elem(0)
  end

  defp show_step(history, step_id) when is_binary(step_id) do
    show_step(history,  String.to_atom(step_id))
  end
  
  defp show_step(history, step_id) when is_atom(step_id) do
    step = history[step_id]

    IO.puts "\tTrigger:  #{inspect step.trigger}"
    IO.puts "\tModel:    #{inspect step.old_model}"
    IO.puts "\tResult:   #{inspect step.result}"

    if step.old_model == step.new_model do
      IO.puts "\tNew model:  «unchanged»"
    else
      ExUnit.Diff.script(inspect(step.old_model), inspect(step.new_model))
      |> List.flatten
      |> Enum.map(&convert_fragment/1)
      |> (&IO.puts("\tChanges:  #{&1}")).()
    end
  end

  defp convert_fragment({:eq,  str}), do: IO.ANSI.format([:green, str])
  defp convert_fragment({:del, str}), do: IO.ANSI.format([:magenta, :inverse, str, :normal])
  defp convert_fragment({:ins, str}), do: IO.ANSI.format([:bright, :white, str, :normal])


  defp dump_history(history) do
    history
    |> Enum.each(&format_one_step(&1))
    IO.puts ""
  end

  defp format_one_step({ number, step}) do
    header   = "#{number}" |> String.pad_leading(6)
    trigger  = step.trigger |> inspect |> String.pad_leading(27)
    modified = if step.old_model == step.new_model, do: "•", else: "►"
    IO.puts "#{header} #{modified} #{trigger} → #{inspect step.result}"
  end

  ## Clone support

  defp rollback_to([], _number), do: []
  defp rollback_to(history = [{ number, _ } | _rest], number), do: history
  defp rollback_to([ _ | rest], number), do: rollback_to(rest, number)

  def show_clone(state, number) do
    flag = if state.current == number, do: "*", else: " "
    history = state.steppers[number].history
    step = most_recent_step(history)
    IO.puts "#{flag} #{number}\tStep #:   #{step}"
    show_step(history, step)
    IO.puts ""
  end


  defp stepper(state), do: state.steppers[state.current]
end
