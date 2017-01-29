defmodule Diet.Transformations do

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
    use Diet.Transformations

    transforms do

      { :rle, {[], result} } ->
              {:done, result |> Enum.reverse}

      { :rle, {[ {a, n}, a | tail], result }} ->
              {:rle, {[{a, n+1} | tail], result}}

      { :rle, {[ a, a | tail ], result } } ->
              {:rle, {[{a, 2} | tail], result }}

      { :rle, {[a | tail ], result } } ->
              {:rle, {tail, [a | result]  }}

      { :rle, list } ->
              {:rle, {list, []}}
    end

  end
  ~~~

  In the RLE example, the atom `:rle` is actually not needed at the
  fron of each tuple.
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

  defmacro transforms(opts \\ [], do: body) do
    steps = for {:->, _, [ [lhs], rhs ]} <- body do
      generate_step(lhs, rhs, opts[:debug])
    end
    
    quote do
      unquote_splicing(steps)

      def step({result, model}) do
        unquote(maybe(opts[:debug],
          quote do
            Logger.debug("finished: #{inspect(result)}")
          end))
        { :done, result, model }
      end
    end
  end

  def generate_step(trigger, body, debug) when debug do
    res = quote do
      def step({ unquote(trigger), unquote({:model, [], nil}) }) do
        Logger.debug("handling #{inspect(unquote(trigger))}")

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
    res
  end

  def generate_step(trigger, body, _debug)  do
    res = quote do
      def step({ unquote(trigger), unquote({:model, [], nil}) }) do
        case unquote(body) do
          { :update_model, model, result } ->
            { :continue, result, model }
          result ->
            { :continue, result, unquote({:model, [], nil}) }
        end
      end
    end
    res
  end
  

  def update_model(model, do: return) do
    { :update_model, model, return }
  end

  defmacro __using__(opts) do
    result = [
      standard_header(),
      model_name(opts[:model]),
      model_alias(opts[:model], opts[:as])
    ]

    quote do
      unquote_splicing(result)
    end
  end

  defp model_name(model) do  # may be nil. that's ok.
    quote do
      def rm_model() do
        unquote(model)
      end
    end
  end

  defp model_alias(model, as) when not (is_nil(model) or is_nil(as)) do
    quote do
      alias unquote(model), as: unquote(as)
    end
  end

  defp model_alias(_, _), do: nil


  defp standard_header() do
    quote do
      require Logger
      require unquote(__MODULE__)
      import  unquote(__MODULE__)
    end
  end


  defp maybe(flag, code) when flag, do: code
  defp maybe(_, _), do: nil


end
