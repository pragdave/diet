defmodule Diet.Debug do

  def on(stepper) do
    IO.puts "\nDiet debugger looking at #{stepper.module}\n"
    IO.puts "h for help\n"

    stepper
    |> build_state
    |> interact
  end

  defp build_state(stepper) do

    %{
      name:    stepper.module |> to_string |> String.trim_leading("Elixir."),
      stepper: stepper,
    }
  end

  defp interact(state) do
    res = IO.gets "#{state.name}> "
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

  defp command("t", _, state) do
    state.stepper.history
    |> Enum.reverse
    |> dump_history

    interact(state)
  end

  defp command("h", _, state) do
    IO.puts """

    t       – show execution trace
    n.n     – show details of step n.n
    r «trigger args»
            – run the stepper using the given trigger
    q       – quit
    """
    interact(state)
  end

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
      { result, stepper } = Diet.Stepper.run(state.stepper, arg_val)
      IO.puts "\nResult: #{inspect result, pretty: true}"
      interact(%{ state | stepper: stepper })
    rescue
      e in CompileError ->
        IO.puts "error: #{e.description}\n"
        interact(state)
    end
  end

  defp command("q", _, _state) do
    IO.puts "done\n"
  end

  defp command("", _, state) do
    interact(state)
  end



  defp command(other, _, state) do
    case Regex.run(~r{^(\d+)\.(\d+)$}, other) do

      [_, run, step ] ->
        show_step(Enum.reverse(state.stepper.history),
          String.to_integer(run),
          String.to_integer(step))

      _ ->
        IO.puts "Unknown command #{inspect other}"
    end

    interact(state)
  end

  defp show_step(history, run_index, step_index) do
    run  = Enum.at(history, run_index-1)
    step = Enum.at(run,     step_index-1)

    IO.puts "Trigger:  #{inspect step.trigger}"
    IO.puts "Model:    #{inspect step.old_model}"
    IO.puts "Result:   #{inspect step.result}"

    if step.old_model == step.new_model do
      IO.puts "New model:  «unchanged»"
    else
      ExUnit.Diff.script(inspect(step.old_model), inspect(step.new_model))
      |> List.flatten
      |> Enum.map(&convert_fragment/1)
      |> (&IO.puts("Changes:  #{&1}")).()
    end
  end

  defp convert_fragment({:eq,  str}), do: IO.ANSI.format([:green, str])
  defp convert_fragment({:del, str}), do: IO.ANSI.format([:magenta, :inverse, str, :normal])
  defp convert_fragment({:ins, str}), do: IO.ANSI.format([:bright, :white, str, :normal])


  defp dump_history(history) do
    history
    |> Enum.with_index(1)
    |> Enum.each(&format_one_run/1)
  end

  defp format_one_run({run, index}) do
    run
    |> Enum.with_index(1)
    |> Enum.each(&format_one_step(&1, index))
    IO.puts ""
  end

  defp format_one_step({step, step_index}, run_index) do
    header = "#{run_index}.#{step_index}" |> String.pad_leading(6)
    trigger = step.trigger |> inspect |>String.pad_leading(24)
    modified = if step.old_model == step.new_model, do: "•", else: "►"
    IO.puts "#{header} #{modified} #{trigger} → #{inspect step.result}"
  end
end
