defmodule ReducerMachine.Transformations do

  @moduledoc """
  We define a high-level macro, `transforms`. It takes a `do`-block
  containing a list of `a -> b` expressions (just like `cond` or
  `case`).

  Each entry in this list represents a reduction. The left hand side
  specifies a pattern that must be matched , and the right hand side
  gives the transformation to the model (if any) and then returns the
  new trigger.

  ~~~ elixir
  defmodule RLE do
    use ReducerMachine.Transformations

    transforms do

      { :encode, string } -> { :rle, { String.codepoints(string), [] } }

      { :rle, {[], result} } -> { :done, result |> Enum.reverse |> Enum.join }
      { :rle, {[{a,n},a|tail], result } -> { :rle, {[ {a,n+1} | tail ], result}
      { :rle, {[a,a|tail], result }     -> { :rle, { [ {a,2} | tail ], result }
      { :rle, {[a|tail], result }       -> { :rle, { [ tail, [ a | result ]}

    end
  end
  ~~~

  ## Internals

  Each transform is converted into a function called `step`. This
  function takes the lhs of the transform and the
  model, wrapped in a tuple. So the first transform becomes something like:

  ~~~ elixir
  def step({{ :encode, string }, model}) do
    val = { :rle, { String.codepoints(string), [] } }
    case val do
      { :update_model, model, result } ->
            { :continue, result, model }
      result ->
            { :continue, result, unquote({:model, [], nil}) }
    end
  end
  ~~~

  So! you cry. What's with the `:update_model`?

  If a transform needs to update the model, it has to signal the fact
  by ending the transform code with

  ~~~ elixir
  update_model(new_model_value) do
    «return value»
  end
  ~~~

  The `update_model` function then returns a tuple starting
  `:update_model`, which tells the step code to replace the model with
  the new value when it returns.
  """

  defmacro transforms(do: body) do
    steps = for {:->, _, [ [lhs], rhs ]} <- body do
      generate_step(lhs, rhs)
    end
    
    quote do
      unquote_splicing(steps)

      def step({result, model}) do
        Logger.debug("finished: #{inspect(result)}")
        { :done, result, model }
      end
    end
  end

  def generate_step(trigger, body) do
    #      IO.inspect body, pretty: true
    res = quote do
      def step({ unquote(trigger), unquote({:model, [], nil}) }) do
        Logger.debug("handling #{inspect unquote(trigger)}")
        case unquote(body) do
          { :update_model, model, result } ->
            Logger.debug("   new model: #{inspect model}")
            Logger.debug("   => #{inspect result}")
            { :continue, result, model }
          result ->
            Logger.debug("   => #{inspect result}")
            { :continue, result, unquote({:model, [], nil}) }
        end
      end
    end
    #      IO.inspect res, pretty: true
    #      IO.puts Macro.to_string(res)
    res
  end

  defmacro start_with(name) when is_atom(name) do
    quote do
      def first_step() do
        unquote(name)
      end
    end
  end

  def update_model(model, do: return) do
    { :update_model, model, return }
  end

  defmacro __using__(_opts) do
    quote do
      require Logger
      require unquote(__MODULE__)
      import  unquote(__MODULE__)
    end
  end
end
