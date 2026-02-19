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

  test "parses bracket-notation fields for subselect configuration" do
    selecto = test_selecto()

    updated = SubselectBuilder.add_subselect_for_group(selecto, "posts", ["posts[title]"])
    [config] = Selecto.Subselect.get_subselect_configs(updated)

    assert config.target_schema == :posts
    assert config.fields == ["title"]
    assert config.alias == "posts"
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
  end
end
