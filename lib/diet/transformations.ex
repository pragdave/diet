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

  defmacro reductions(opts \\ [], do: body) do
    model_name = opts[:model_name] || :model
    model_name = { model_name, [], nil }

    steps = for {:->, _, [ [lhs], rhs ]} <- body do
      generate_step(lhs, rhs, opts[:debug], model_name)
    end

    quote do
      unquote_splicing(steps)
    
      def step({result, unquote(model_name)}) do
        unquote(maybe(opts[:debug],
          quote do
            Logger.debug("finished: #{inspect(result)}")
          end))
        { :done, result, unquote(model_name) }
      end
    end

  end

  def generate_step(trigger, body, debug, model_name) when debug do
    body = quote do
        Logger.debug("handling #{inspect(unquote(trigger))}")

        case unquote(body) do
          { :update_model, model, result } ->
            Logger.debug("   new model: #{inspect unquote(model_name)}")
            Logger.debug("   => #{inspect result}")
            { :continue, result, unquote(model_name) }
          result ->
            Logger.debug("   => #{inspect result}")
            { :continue, result, unquote(model_name) }
        end
    end

    generate_full_step(trigger, body, model_name)
  end

  def generate_step(trigger, body, _debug, model_name)  do
    body = quote do
      case unquote(body) do
        { :update_model, unquote(model_name), result } ->
          { :continue, result, unquote(model_name) }
        result ->
          { :continue, result, unquote(model_name) }
      end
    end

    generate_full_step(trigger, body, model_name)
  end


  defp generate_full_step({:when, _, [ trigger, when_clause ]}, body, model_name) do
    quote do
      def step(unquote(add_model_to(trigger, model_name)))
          when unquote(when_clause) do
        unquote(body)
      end
    end
  end

  defp generate_full_step(trigger, body, model_name) do
    quote do
      def step(unquote(add_model_to(trigger, model_name))) do
        unquote(body)
      end
    end
  end

  defp add_model_to(trigger, model_name) do
    quote do
      {
        unquote(trigger),
        unquote(model_name)
      }
    end
  end

  def update_model(model, do: return) do
    { :update_model, model, return }
  end

  defmacro __using__(opts) do
    result = [
      standard_header(),
      model_name(opts[:model]),
      model_as(opts[:model], opts[:as]),
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


  defp model_as(model, as) when not (is_nil(model) or is_nil(as)) do
    quote do
      alias unquote(model), as: unquote(as)
    end
  end

  defp model_as(_, _), do: nil


  defp standard_header() do
    quote do
      require Logger
      require Diet.Transformations
      import  Diet.Transformations
    end
  end


  defp maybe(flag, code) when flag, do: code
  defp maybe(_, _), do: nil


end
