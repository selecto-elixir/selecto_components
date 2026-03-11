defmodule SelectoComponents.Views.Detail.ProcessTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Detail.Process

  defp test_selecto do
    domain = %{
      source: %{
        source_table: "users",
        primary_key: :user_id,
        fields: [:user_id, :name],
        redact_fields: [],
        columns: %{
          user_id: %{type: :integer},
          name: %{type: :string}
        },
        associations: %{
          posts: %{
            queryable: :posts,
            field: :posts,
            owner_key: :user_id,
            related_key: :user_id
          }
        }
      },
      schemas: %{
        posts: %{
          source_table: "posts",
          primary_key: :post_id,
          fields: [:post_id, :user_id, :title],
          redact_fields: [],
          columns: %{
            post_id: %{type: :integer},
            user_id: %{type: :integer},
            title: %{type: :string}
          },
          associations: %{}
        }
      },
      name: "User",
      joins: %{
        posts: %{type: :left, name: "posts"}
      }
    }

    Selecto.configure(domain, [hostname: "localhost"], validate: false)
  end

  defp view_columns do
    %{
      "name" => %{type: :string, colid: "name"},
      "posts.title" => %{type: :string, colid: "posts.title"},
      "created_at" => %{type: :utc_datetime, colid: "created_at"}
    }
  end

  test "checked prevent_denormalization moves fan-out columns into subselect config" do
    selecto = test_selecto()

    params = %{
      "selected" => %{
        "c1" => %{"field" => "name", "index" => "0", "alias" => "", "uuid" => "c1"},
        "c2" => %{"field" => "posts.title", "index" => "1", "alias" => "", "uuid" => "c2"}
      },
      "order_by" => %{},
      "per_page" => "30",
      "max_rows" => "1000",
      "prevent_denormalization" => "on"
    }

    {view_set, view_meta} = Process.view(nil, params, view_columns(), [], selecto)

    selected_fields = Enum.map(view_set.columns, & &1["field"])

    assert selected_fields == ["name"]
    assert view_set.denorm_groups == %{"posts" => ["posts.title"]}
    assert view_meta.prevent_denormalization == true
    assert view_meta.max_rows == "1000"
    assert view_meta.count_mode == "bounded"
    assert [%{key: "posts"}] = view_meta.subselect_configs
  end

  test "unchecked prevent_denormalization keeps related columns in flat result" do
    selecto = test_selecto()

    params = %{
      "selected" => %{
        "c1" => %{"field" => "name", "index" => "0", "alias" => "", "uuid" => "c1"},
        "c2" => %{"field" => "posts.title", "index" => "1", "alias" => "", "uuid" => "c2"}
      },
      "order_by" => %{},
      "per_page" => "30",
      "max_rows" => "all"
    }

    {view_set, view_meta} = Process.view(nil, params, view_columns(), [], selecto)

    selected_fields = Enum.map(view_set.columns, & &1["field"])

    assert selected_fields == ["name", "posts.title"]
    assert view_set.denorm_groups == %{}
    assert view_meta.prevent_denormalization == false
    assert view_meta.max_rows == "all"
    assert view_meta.count_mode == "bounded"
    assert view_meta.subselect_configs == []
  end

  test "checked prevent_denormalization supports dotted relationship column names" do
    selecto = test_selecto()

    params = %{
      "selected" => %{
        "c1" => %{"field" => "name", "index" => "0", "alias" => "", "uuid" => "c1"},
        "c2" => %{"field" => "posts.title", "index" => "1", "alias" => "", "uuid" => "c2"}
      },
      "order_by" => %{},
      "per_page" => "30",
      "max_rows" => "10000",
      "prevent_denormalization" => "on"
    }

    {view_set, view_meta} = Process.view(nil, params, view_columns(), [], selecto)

    selected_fields = Enum.map(view_set.columns, & &1["field"])

    assert selected_fields == ["name"]
    assert view_set.denorm_groups == %{"posts" => ["posts.title"]}
    assert view_meta.max_rows == "10000"
    assert view_meta.count_mode == "bounded"
    assert [%{key: "posts"}] = view_meta.subselect_configs
  end

  test "missing max_rows falls back to default" do
    selecto = test_selecto()

    params = %{
      "selected" => %{
        "c1" => %{"field" => "name", "index" => "0", "alias" => "", "uuid" => "c1"}
      },
      "order_by" => %{},
      "per_page" => "30"
    }

    {_view_set, view_meta} = Process.view(nil, params, view_columns(), [], selecto)

    assert view_meta.max_rows == "1000"
    assert view_meta.count_mode == "bounded"
  end

  test "selected entries inherit uuid from param keys when missing in payload" do
    selecto = test_selecto()

    params = %{
      "selected" => %{
        "c1" => %{"field" => "name", "index" => "0", "alias" => ""},
        "c2" => %{"field" => "posts.title", "index" => "1", "alias" => ""}
      },
      "order_by" => %{},
      "per_page" => "30"
    }

    {view_set, _view_meta} = Process.view(nil, params, view_columns(), [], selecto)

    uuids = Enum.map(view_set.columns, & &1["uuid"])

    assert uuids == ["c1", "c2"]
  end

  test "selected tuple list entries normalize into map configs" do
    selecto = test_selecto()

    params = %{
      "selected" => [
        {"c1", "name", %{}},
        {"c2", "posts.title", %{}}
      ],
      "order_by" => %{},
      "per_page" => "30"
    }

    {view_set, _view_meta} = Process.view(nil, params, view_columns(), [], selecto)

    assert Enum.map(view_set.columns, & &1["uuid"]) == ["c1", "c2"]
    assert Enum.map(view_set.columns, & &1["field"]) == ["name", "posts.title"]
  end

  test "count_mode param is normalized in view meta" do
    selecto = test_selecto()

    params = %{
      "selected" => %{
        "c1" => %{"field" => "name", "index" => "0", "alias" => "", "uuid" => "c1"}
      },
      "order_by" => %{},
      "per_page" => "30",
      "count_mode" => "exact"
    }

    {_view_set, view_meta} = Process.view(nil, params, view_columns(), [], selecto)

    assert view_meta.count_mode == "exact"
  end

  test "detail datetime format supports aggregate day-of-week token" do
    selecto = test_selecto()

    params = %{
      "selected" => %{
        "c1" => %{"field" => "created_at", "index" => "0", "alias" => "", "format" => "D"}
      },
      "order_by" => %{},
      "per_page" => "30"
    }

    {view_set, _view_meta} = Process.view(nil, params, view_columns(), [], selecto)

    assert [{:field, {:to_char, {"created_at", "D"}}, "created_at"}] = view_set.selected
  end
end
