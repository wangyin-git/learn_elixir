defmodule Meal.String do
  require Meal

  use Meal.Delegate,
    to: String,
    except: [
      ljust: 2,
      ljust: 3,
      lstrip: 1,
      lstrip: 2,
      next_grapheme_size: 1,
      rjust: 2,
      rjust: 3,
      rstrip: 1,
      rstrip: 2,
      strip: 1,
      strip: 2,
      to_char_list: 1,
      valid_character?: 1
    ]

  def indexOf(str, pattern, pos \\ 0)

  def indexOf(str, %Regex{} = pattern, pos)
      when is_binary(str) and Meal.is_non_neg_integer(pos) do
    case Regex.run(pattern, str, return: :index, offset: pos) do
      nil -> nil
      [{start, _}] -> start
    end
  end

  def indexOf(str, pattern, pos)
      when is_binary(str) and is_binary(pattern) and Meal.is_non_neg_integer(pos) do
    indexOf(str, ~r/#{Regex.escape(pattern)}/, pos)
  end

  def replace_slice(str, first..last//_, replacement)
      when is_binary(str) and is_binary(replacement) do
    len = String.length(str)

    with first when first >= 0 and first < len <- Meal.Enum.normalize_index(1..len//1, first),
         last when first <= last <- Meal.Enum.normalize_index(1..len//1, last) do
      left_count = Range.size(0..(first - 1)//1)
      slice(str, 0, left_count) <> replacement <> slice(str, (last + 1)..-1)
    else
      _ -> str
    end
  end

  def replace_slice(str, start, length, replacement)
      when is_integer(start) and is_integer(length) and is_binary(replacement) do
    cond do
      length == 0 ->
        str

      length < 0 ->
        replace_slice(str, start..-1, replacement)

      length > 0 && start >= 0 ->
        replace_slice(str, start..(start + length - 1), replacement)

      length > 0 && start < 0 && start + length - 1 < 0 ->
        replace_slice(str, start..(start + length - 1), replacement)

      length > 0 && start < 0 && start + length - 1 >= 0 ->
        replace_slice(str, start..-1, replacement)
    end
  end

  def delete_slice(str, first..last//_) when is_binary(str) do
    replace_slice(str, first..last, "")
  end

  def delete_slice(str, start, length)
      when is_binary(str) and is_integer(start) and is_integer(length) do
    replace_slice(str, start, length, "")
  end

  def insert_at(str, index, content)
      when is_binary(str) and is_integer(index) and is_binary(content) do
    String.graphemes(str)
    |> List.insert_at(index, content)
    |> Enum.join()
  end
end

defmodule Meal.String.Stream do
  def bytes(str) when is_binary(str) do
    Stream.unfold(
      str,
      fn
        "" ->
          nil

        <<byte::8, rest::binary>> ->
          {byte, rest}
      end
    )
  end

  def codepoints(str) when is_binary(str) do
    Stream.unfold(str, &String.next_codepoint/1)
  end

  def graphemes(str) when is_binary(str) do
    Stream.unfold(str, &String.next_grapheme/1)
  end

  def lines(str) do
    lines(str, separator: "\n", chomp: false)
  end

  def lines(str, separator: separator) when is_binary(separator) do
    lines(str, separator: separator, chomp: false)
  end

  def lines(str, chomp: chomp) when is_boolean(chomp) do
    lines(str, separator: "\n", chomp: chomp)
  end

  def lines(str, separator: separator, chomp: chomp)
      when is_binary(str) and is_binary(separator) and is_boolean(chomp) do
    {:ok, regex} = Regex.compile(Regex.escape(separator))

    Stream.unfold(
      str,
      fn
        "" ->
          nil

        str ->
          case Regex.split(regex, str, parts: 2) do
            [left, right] -> if chomp, do: {left, right}, else: {left <> separator, right}
            [left] -> {left, ""}
          end
      end
    )
  end
end
