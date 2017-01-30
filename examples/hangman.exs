defmodule Hangman do

  Code.require_file "hangman_model.exs"

  use Diet.Transformations, model: HangmanModel, as: HM

  transforms(debug: false) do

    { :make_move, move } ->
            if HM.already_used_letter?(model, move) do
              { :already_tried, move }
            else
              { :record_move,   move }
            end

    { :record_move, move } ->
            update_model(HM.use_letter(model, move)) do
              { :maybe_match, move }
            end

    { :maybe_match, move } ->
            if HM.letter_in_word?(model, move) do
              :match
            else
              :no_match
            end

    :match ->
            if HM.game_won?(model) do
              :game_won
            else
              :good_guess
            end

    :no_match ->
            if HM.out_of_turns?(model) do
              :game_lost
            else
              update_model(HM.one_less_turn(model)) do
                :bad_guess
              end
            end
  end
end


alias Diet.Stepper

stepper = Stepper.new(Hangman,  "wombat")

{ result, stepper } = Stepper.run(stepper, { :make_move, "w" })
IO.inspect result  # => :good_guess

{ result, stepper } = Stepper.run(stepper, { :make_move, "x" })
IO.inspect result  # => :bad_guess

{ result, stepper } = Stepper.run(stepper, { :make_move, "x" })
IO.inspect result  # => { :already_tried, "x" }

{ _     , stepper } = Stepper.run(stepper, { :make_move, "o" })
{ _     , stepper } = Stepper.run(stepper, { :make_move, "m" })
{ _     , stepper } = Stepper.run(stepper, { :make_move, "b" })
{ _     , stepper } = Stepper.run(stepper, { :make_move, "a" })
{ result, stepper } = Stepper.run(stepper, { :make_move, "t" })
IO.inspect result  # => :game_won

IO.puts ""

stepper.history
|> Enum.reverse
|> Enum.map(&Enum.reverse/1)
|> Enum.map(&inspect(&1, pretty: true))
|> Enum.join("\n\n")
|> IO.puts()
