defmodule Meal.String do
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
  def byte_at(str, pos) when is_binary(str) and is_integer(pos) do
    pos = Meal.normalize_index(1..byte_size(str), pos)
    if pos >= 0 && pos < byte_size(str) do
      <<_ :: binary - size(pos), byte :: 8, _ :: binary>> = str
      byte
    else
      nil
    end
  end

  def byte_slice(str, first..last) when is_binary(str) do
    size = byte_size(str)
    result = with first when first >= 0 and first < size <- Meal.normalize_index(1..size, first),
                  last when first <= last <- Meal.normalize_index(1..size, last) do
      len = min(size - first, last - first + 1)
      <<_ :: binary - size(first), bytes :: binary - size(len), _ :: binary>> = str
      bytes
    end
    case result do
      bytes when is_binary(bytes) -> bytes
      _ -> ""
    end
  end

  def byte_slice(str, start, length) when is_integer(start) and is_integer(length) do
    cond do
      length == 0 -> ""
      length < 0 -> byte_slice(str, start..-1)
      length > 0 -> byte_slice(str, start..(start + length - 1))
    end
  end
end

defmodule Meal.String.Stream do
  def bytes(str) when is_binary(str) do
    Stream.unfold(
      str,
      fn
        "" -> nil
        <<byte :: 8, rest :: binary>> ->
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
