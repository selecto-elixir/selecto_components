defmodule SelectoComponents.SubselectBuilderTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.SubselectBuilder

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

  test "parses dotted fields for subselect configuration" do
    selecto = test_selecto()

    updated = SubselectBuilder.add_subselect_for_group(selecto, "posts", ["posts.title"])
    [config] = Selecto.Subselect.get_subselect_configs(updated)

    assert config.target_schema == :posts
    assert config.fields == ["title"]
    assert config.alias == "posts"
    assert config.join_path == [:posts]
  end

  test "resolves schema from dotted relationship paths" do
    selecto = test_selecto()

    updated =
      SubselectBuilder.add_subselect_for_group(selecto, "source.posts", [
        "source.posts.title",
        "source.posts.user_id"
      ])

    [config] = Selecto.Subselect.get_subselect_configs(updated)

    assert config.target_schema == :posts
    assert config.fields == ["title", "user_id"]
    assert config.alias == "source.posts"
    assert config.join_path == [:posts]
  end

  test "preserves nested join paths when the same schema appears twice" do
    domain = %{
      source: %{
        source_table: "workspaces",
        primary_key: :id,
        fields: [:id, :name],
        redact_fields: [],
        columns: %{id: %{type: :integer}, name: %{type: :string}},
        associations: %{
          members: %{
            queryable: :employee,
            field: :members,
            owner_key: :id,
            related_key: :workspace_id
          }
        }
      },
      schemas: %{
        employee: %{
          source_table: "employees",
          primary_key: :id,
          fields: [:id, :full_name, :workspace_id, :manager_id],
          redact_fields: [],
          columns: %{
            id: %{type: :integer},
            full_name: %{type: :string},
            workspace_id: %{type: :integer},
            manager_id: %{type: :integer}
          },
          associations: %{
            manager: %{
              queryable: :employee,
              field: :manager,
              owner_key: :manager_id,
              related_key: :id
            }
          }
        }
      },
      name: "Workspace",
      joins: %{members: %{type: :left, name: "members"}}
    }

    selecto =
      Selecto.configure(domain, [hostname: "localhost"], validate: false)
      |> then(fn base ->
        joins = %{
          members: %{
            type: :left,
            name: "members",
            source: "employees",
            my_key: :id,
            requires_join: :selecto_root,
            fields: %{}
          },
          manager: %{
            type: :left,
            name: "manager",
            source: "employees",
            my_key: :manager_id,
            requires_join: :members,
            fields: %{}
          }
        }

        %{base | config: Map.put(base.config, :joins, joins)}
      end)

    updated =
      SubselectBuilder.add_subselect_for_group(
        selecto,
        "members.manager",
        ["manager.full_name"]
      )

    [config] = Selecto.Subselect.get_subselect_configs(updated)

    assert config.target_schema == :employee
    assert config.fields == ["full_name"]
    assert config.alias == "members.manager"
    assert config.join_path == [:members, :manager]
  end
end
