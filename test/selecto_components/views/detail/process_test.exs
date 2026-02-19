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
      "posts[title]" => %{type: :string, colid: "posts[title]"}
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
      "prevent_denormalization" => "on"
    }

    {view_set, view_meta} = Process.view(nil, params, view_columns(), [], selecto)

    selected_fields = Enum.map(view_set.columns, & &1["field"])

    assert selected_fields == ["name"]
    assert view_set.denorm_groups == %{"posts" => ["posts.title"]}
    assert view_meta.prevent_denormalization == true
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
      "per_page" => "30"
    }

    {view_set, view_meta} = Process.view(nil, params, view_columns(), [], selecto)

    selected_fields = Enum.map(view_set.columns, & &1["field"])

    assert selected_fields == ["name", "posts.title"]
    assert view_set.denorm_groups == %{}
    assert view_meta.prevent_denormalization == false
    assert view_meta.subselect_configs == []
  end

  test "checked prevent_denormalization supports bracket column names" do
    selecto = test_selecto()

    params = %{
      "selected" => %{
        "c1" => %{"field" => "name", "index" => "0", "alias" => "", "uuid" => "c1"},
        "c2" => %{"field" => "posts[title]", "index" => "1", "alias" => "", "uuid" => "c2"}
      },
      "order_by" => %{},
      "per_page" => "30",
      "prevent_denormalization" => "on"
    }

    {view_set, view_meta} = Process.view(nil, params, view_columns(), [], selecto)

    selected_fields = Enum.map(view_set.columns, & &1["field"])

    assert selected_fields == ["name"]
    assert view_set.denorm_groups == %{"posts" => ["posts[title]"]}
    assert [%{key: "posts"}] = view_meta.subselect_configs
  end
end
