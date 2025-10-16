defmodule WeaviateEx.Fixtures do
  @moduledoc """
  Test fixtures for Weaviate objects and responses.
  """

  @doc """
  Returns a sample collection (schema class) definition.
  """
  def collection_fixture(name \\ "Article") do
    %{
      "class" => name,
      "description" => "A collection for #{name} objects",
      "properties" => [
        %{
          "name" => "title",
          "dataType" => ["text"],
          "description" => "The title"
        },
        %{
          "name" => "content",
          "dataType" => ["text"],
          "description" => "The content"
        }
      ],
      "vectorizer" => "none"
    }
  end

  @doc """
  Returns a sample object.
  """
  def object_fixture(class_name \\ "Article") do
    %{
      "class" => class_name,
      "id" => "00000000-0000-0000-0000-000000000001",
      "properties" => %{
        "title" => "Test Article",
        "content" => "This is test content"
      },
      "vector" => [0.1, 0.2, 0.3, 0.4, 0.5]
    }
  end

  @doc """
  Returns a batch of sample objects.
  """
  def batch_objects_fixture(class_name \\ "Article", count \\ 3) do
    Enum.map(1..count, fn i ->
      %{
        "class" => class_name,
        "id" => uuid(i),
        "properties" => %{
          "title" => "Test Article #{i}",
          "content" => "This is test content #{i}"
        },
        "vector" => Enum.map(1..5, fn _ -> :rand.uniform() end)
      }
    end)
  end

  @doc """
  Returns a sample meta response.
  """
  def meta_fixture do
    %{
      "hostname" => "http://[::]:8080",
      "modules" => %{},
      "version" => "1.28.1"
    }
  end

  @doc """
  Returns a sample GraphQL query response.
  """
  def graphql_response_fixture(class_name \\ "Article") do
    %{
      "data" => %{
        "Get" => %{
          class_name => [
            %{
              "title" => "Test Article 1",
              "content" => "Content 1",
              "_additional" => %{
                "id" => uuid(1)
              }
            },
            %{
              "title" => "Test Article 2",
              "content" => "Content 2",
              "_additional" => %{
                "id" => uuid(2)
              }
            }
          ]
        }
      }
    }
  end

  @doc """
  Returns a sample error response.
  """
  def error_response_fixture(message \\ "Something went wrong") do
    %{
      "error" => [
        %{
          "message" => message
        }
      ]
    }
  end

  # Helper to generate consistent UUIDs for testing
  defp uuid(_n) do
    Uniq.UUID.uuid4()
  end
end
