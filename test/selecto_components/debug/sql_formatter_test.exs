defmodule SelectoComponents.Debug.SqlFormatterTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Debug.SqlFormatter

  test "formats select, joins, predicates, ordering, and limits on indented lines" do
    sql =
      "select users.id, users.name from users left join roles on roles.id = users.role_id where users.active = true and users.name ilike $1 order by users.name limit 10"

    expected =
      """
      SELECT
        users.id,
        users.name
      FROM
        users
        LEFT JOIN roles
          ON roles.id = users.role_id
      WHERE
        users.active = TRUE
        AND users.name ILIKE $1
      ORDER BY
        users.name
      LIMIT 10
      """
      |> String.trim()

    assert SqlFormatter.format(sql) == expected
  end

  test "keeps function arguments together while breaking top-level select items" do
    sql = "select count(*), coalesce(users.name, 'unknown') as name from users"

    expected =
      """
      SELECT
        COUNT(*),
        coalesce(users.name, 'unknown') AS name
      FROM
        users
      """
      |> String.trim()

    assert SqlFormatter.format(sql) == expected
  end
end
