defmodule SelectoComponents.DenormalizationDetectorTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.DenormalizationDetector

  defp test_selecto do
    domain = %{
      source: %{
        source_table: "users",
        primary_key: :user_id,
        fields: [:user_id, :name, :profile_id],
        redact_fields: [],
        columns: %{
          user_id: %{type: :integer},
          name: %{type: :string},
          profile_id: %{type: :integer}
        },
        associations: %{
          posts: %{
            queryable: :posts,
            field: :posts,
            owner_key: :user_id,
            related_key: :user_id
          },
          profile: %{
            queryable: :profiles,
            field: :profile,
            owner_key: :profile_id,
            related_key: :profile_id
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
        },
        profiles: %{
          source_table: "profiles",
          primary_key: :profile_id,
          fields: [:profile_id, :display_name],
          redact_fields: [],
          columns: %{
            profile_id: %{type: :integer},
            display_name: %{type: :string}
          },
          associations: %{}
        }
      },
      name: "User",
      joins: %{
        posts: %{type: :left, name: "posts"},
        profile: %{type: :left, name: "profile"}
      }
    }

    Selecto.configure(domain, [hostname: "localhost"], validate: false)
  end

  test "groups fan-out columns into denormalized buckets" do
    selecto = test_selecto()

    {normal_columns, denorm_groups} =
      DenormalizationDetector.detect_and_group_columns(selecto, ["name", "posts.title"])

    assert "name" in normal_columns
    refute "posts.title" in normal_columns
    assert denorm_groups == %{"posts" => ["posts.title"]}
  end

  test "keeps one-to-one style joined columns in normal columns" do
    selecto = test_selecto()

    {normal_columns, denorm_groups} =
      DenormalizationDetector.detect_and_group_columns(selecto, ["name", "profile.display_name"])

    assert "profile.display_name" in normal_columns
    assert denorm_groups == %{}
  end
end
