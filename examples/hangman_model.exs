defmodule HangmanModel do

  defstruct(
    word_to_guess:  [],
    guessed_so_far: MapSet.new(),
    turns_left:     7
  )

  def build(word) do
    %__MODULE__{
      word_to_guess: word |> String.codepoints,
    }
  end

  def already_used_letter?(model, letter) do
    MapSet.member?(model.guessed_so_far, letter)
  end

  def use_letter(model, letter) do
    update_in(model.guessed_so_far, &MapSet.put(&1, letter))
  end

  def letter_in_word?(model, letter) do
    Enum.member?(model.word_to_guess, letter)
  end

  def one_less_turn(model) do
    %{ model | turns_left: model.turns_left - 1 }
  end

  def game_won?(model) do
    model.word_to_guess |> Enum.all?(&MapSet.member?(model.guessed_so_far, &1))
  end

  def out_of_turns?(%{turns_left: turns_left}) do
    turns_left <= 1
  end

end
