defmodule SelectoComponents.Debug.SqlFormatter do
  @moduledoc """
  Lightweight SQL formatter for debug displays.

  This is intentionally conservative: it preserves SQL text and only adds line
  breaks/indentation around common clauses so generated queries are readable in
  the debug panel.
  """

  @major_clauses MapSet.new([
                   "WITH",
                   "WITH RECURSIVE",
                   "SELECT",
                   "FROM",
                   "WHERE",
                   "GROUP BY",
                   "ORDER BY",
                   "HAVING"
                 ])

  @inline_clauses MapSet.new([
                    "LIMIT",
                    "OFFSET",
                    "FETCH",
                    "RETURNING",
                    "UNION",
                    "UNION ALL",
                    "INTERSECT",
                    "EXCEPT"
                  ])

  @join_clauses MapSet.new([
                  "JOIN",
                  "INNER JOIN",
                  "LEFT JOIN",
                  "LEFT OUTER JOIN",
                  "RIGHT JOIN",
                  "RIGHT OUTER JOIN",
                  "FULL JOIN",
                  "FULL OUTER JOIN",
                  "CROSS JOIN",
                  "LATERAL JOIN"
                ])

  @keywords MapSet.new([
              "ALL",
              "ALTER",
              "AND",
              "ANY",
              "AS",
              "ASC",
              "AVG",
              "BEGIN",
              "BETWEEN",
              "BY",
              "CASE",
              "COMMIT",
              "COUNT",
              "CREATE",
              "DELETE",
              "DESC",
              "DISTINCT",
              "DROP",
              "ELSE",
              "END",
              "EXCEPT",
              "EXISTS",
              "FALSE",
              "FETCH",
              "FOREIGN",
              "FROM",
              "FULL",
              "GROUP",
              "HAVING",
              "ILIKE",
              "IN",
              "INDEX",
              "INNER",
              "INSERT",
              "INTERSECT",
              "INTO",
              "IS",
              "JOIN",
              "KEY",
              "LATERAL",
              "LEFT",
              "LIKE",
              "LIMIT",
              "MAX",
              "MIN",
              "NOT",
              "NULL",
              "OFFSET",
              "ON",
              "OR",
              "ORDER",
              "OUTER",
              "PRIMARY",
              "RECURSIVE",
              "REFERENCES",
              "RETURNING",
              "RIGHT",
              "ROLLBACK",
              "SELECT",
              "SET",
              "SUM",
              "TABLE",
              "THEN",
              "TRUE",
              "UNION",
              "UPDATE",
              "VALUES",
              "WHEN",
              "WHERE",
              "WITH"
            ])

  @token_pattern ~r/'(?:''|[^'])*'|"(?:""|[^"])*"|\$\d+|::|<=|>=|<>|!=|[(),]|\b\d+(?:\.\d+)?\b|\b[A-Za-z_][A-Za-z0-9_.$]*\b|[-+*\/%=<>]|\S/u

  @spec format(String.t()) :: String.t()
  def format(sql) when is_binary(sql) do
    sql
    |> tokenize()
    |> normalize_keywords()
    |> collapse_compound_clauses()
    |> render_tokens()
  end

  def format(sql), do: to_string(sql || "")

  defp tokenize(sql) do
    @token_pattern
    |> Regex.scan(sql)
    |> List.flatten()
  end

  defp normalize_keywords(tokens) do
    Enum.map(tokens, fn token ->
      upper = String.upcase(token)

      if MapSet.member?(@keywords, upper), do: upper, else: token
    end)
  end

  defp collapse_compound_clauses(tokens), do: collapse_compound_clauses(tokens, [])

  defp collapse_compound_clauses(["WITH", "RECURSIVE" | rest], acc),
    do: collapse_compound_clauses(rest, ["WITH RECURSIVE" | acc])

  defp collapse_compound_clauses(["GROUP", "BY" | rest], acc),
    do: collapse_compound_clauses(rest, ["GROUP BY" | acc])

  defp collapse_compound_clauses(["ORDER", "BY" | rest], acc),
    do: collapse_compound_clauses(rest, ["ORDER BY" | acc])

  defp collapse_compound_clauses(["UNION", "ALL" | rest], acc),
    do: collapse_compound_clauses(rest, ["UNION ALL" | acc])

  defp collapse_compound_clauses(["LEFT", "OUTER", "JOIN" | rest], acc),
    do: collapse_compound_clauses(rest, ["LEFT OUTER JOIN" | acc])

  defp collapse_compound_clauses(["RIGHT", "OUTER", "JOIN" | rest], acc),
    do: collapse_compound_clauses(rest, ["RIGHT OUTER JOIN" | acc])

  defp collapse_compound_clauses(["FULL", "OUTER", "JOIN" | rest], acc),
    do: collapse_compound_clauses(rest, ["FULL OUTER JOIN" | acc])

  defp collapse_compound_clauses(["INNER", "JOIN" | rest], acc),
    do: collapse_compound_clauses(rest, ["INNER JOIN" | acc])

  defp collapse_compound_clauses(["LEFT", "JOIN" | rest], acc),
    do: collapse_compound_clauses(rest, ["LEFT JOIN" | acc])

  defp collapse_compound_clauses(["RIGHT", "JOIN" | rest], acc),
    do: collapse_compound_clauses(rest, ["RIGHT JOIN" | acc])

  defp collapse_compound_clauses(["FULL", "JOIN" | rest], acc),
    do: collapse_compound_clauses(rest, ["FULL JOIN" | acc])

  defp collapse_compound_clauses(["CROSS", "JOIN" | rest], acc),
    do: collapse_compound_clauses(rest, ["CROSS JOIN" | acc])

  defp collapse_compound_clauses(["LATERAL", "JOIN" | rest], acc),
    do: collapse_compound_clauses(rest, ["LATERAL JOIN" | acc])

  defp collapse_compound_clauses([token | rest], acc),
    do: collapse_compound_clauses(rest, [token | acc])

  defp collapse_compound_clauses([], acc), do: Enum.reverse(acc)

  defp render_tokens(tokens) do
    initial_state = %{
      lines: [],
      current: "",
      paren_depth: 0,
      base_indent: 0,
      continuation_indent: 1,
      previous_token: nil
    }

    tokens
    |> Enum.reduce(initial_state, &render_token/2)
    |> finish()
  end

  defp render_token(token, state) when token in ["WITH", "WITH RECURSIVE", "SELECT"] do
    state
    |> start_line(state.paren_depth)
    |> append_token(token)
    |> Map.put(:base_indent, state.paren_depth)
    |> Map.put(:continuation_indent, state.paren_depth + 1)
    |> start_line(state.paren_depth + 1)
  end

  defp render_token(token, state) do
    cond do
      MapSet.member?(@major_clauses, token) ->
        state
        |> start_line(state.paren_depth)
        |> append_token(token)
        |> Map.put(:base_indent, state.paren_depth)
        |> Map.put(:continuation_indent, state.paren_depth + 1)
        |> start_line(state.paren_depth + 1)

      MapSet.member?(@inline_clauses, token) ->
        state
        |> start_line(state.paren_depth)
        |> append_token(token)
        |> Map.put(:base_indent, state.paren_depth)
        |> Map.put(:continuation_indent, state.paren_depth + 1)

      MapSet.member?(@join_clauses, token) ->
        state
        |> start_line(state.paren_depth + 1)
        |> append_token(token)
        |> Map.put(:continuation_indent, state.paren_depth + 2)

      token == "ON" ->
        state
        |> start_line(state.paren_depth + 2)
        |> append_token(token)
        |> Map.put(:continuation_indent, state.paren_depth + 2)

      token in ["AND", "OR"] ->
        state
        |> start_line(max(state.continuation_indent, state.paren_depth + 1))
        |> append_token(token)

      token == "," and state.paren_depth == 0 ->
        state
        |> append_token(token)
        |> start_line(state.continuation_indent)

      token == "(" ->
        state
        |> append_token(token)
        |> Map.update!(:paren_depth, &(&1 + 1))

      token == ")" ->
        state
        |> Map.update!(:paren_depth, &max(&1 - 1, 0))
        |> append_token(token)

      true ->
        append_token(state, token)
    end
  end

  defp start_line(state, indent) do
    state = push_current_line(state)
    %{state | current: indent_text(indent), previous_token: nil}
  end

  defp push_current_line(%{current: current} = state) do
    if String.trim(current) == "" do
      state
    else
      %{state | lines: [String.trim_trailing(current) | state.lines], current: ""}
    end
  end

  defp append_token(state, token) do
    separator = separator(state.current, state.previous_token, token)

    %{state | current: state.current <> separator <> token, previous_token: token}
  end

  defp separator(current, previous_token, token) do
    cond do
      String.trim(current) == "" -> ""
      token == "(" and previous_token in ["IN", "EXISTS", "VALUES"] -> " "
      token == "(" -> ""
      previous_token in ["(", "::"] -> ""
      token_without_leading_space?(token) -> ""
      true -> " "
    end
  end

  defp token_without_leading_space?(token), do: token in [",", ")", "::"]

  defp finish(state) do
    state
    |> push_current_line()
    |> Map.fetch!(:lines)
    |> Enum.reverse()
    |> Enum.join("\n")
    |> String.trim()
  end

  defp indent_text(level), do: String.duplicate("  ", max(level, 0))
end
