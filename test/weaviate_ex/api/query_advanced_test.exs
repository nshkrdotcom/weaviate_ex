defmodule WeaviateEx.API.QueryAdvancedTest do
  @moduledoc """
  Tests for advanced query operations (Phase 2).

  Following TDD approach - tests written first, then stub, then implementation.
  """

  use ExUnit.Case, async: true
  import Mox
  import WeaviateEx.Test.Mocks

  alias WeaviateEx.API.QueryAdvanced
  alias WeaviateEx.Protocol.Mock

  setup :verify_on_exit!
  setup :setup_test_client

  describe "near_image/4" do
    test "performs image similarity search with base64 image", %{client: client} do
      # Base64 encoded tiny PNG
      image_data =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/graphql"
        assert body["query"] =~ "nearImage"
        assert body["query"] =~ image_data

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "title" => "Mountain Landscape",
                   "_additional" => %{"distance" => 0.15}
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               QueryAdvanced.near_image(client, "Article", image_data, limit: 5)

      assert is_list(results)
      assert length(results) == 1
      assert hd(results)["title"] == "Mountain Landscape"
    end

    test "handles image search with certainty threshold", %{client: client} do
      image_data = "base64_image_data"

      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "certainty"
        assert body["query"] =~ "0.7"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      assert {:ok, []} =
               QueryAdvanced.near_image(client, "Article", image_data, certainty: 0.7)
    end

    test "handles invalid image data error", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :validation_error, message: "Invalid image format"}}
      end)

      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
               QueryAdvanced.near_image(client, "Article", "invalid_image")
    end

    test "handles connection error during image search", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, _body, _opts ->
        {:error, %WeaviateEx.Error{type: :connection_error}}
      end)

      assert {:error, %WeaviateEx.Error{type: :connection_error}} =
               QueryAdvanced.near_image(client, "Article", "base64_data")
    end
  end

  describe "near_media/5" do
    test "performs audio similarity search", %{client: client} do
      audio_data = "base64_audio_data"

      Mox.expect(Mock, :request, fn _client, :post, path, body, _opts ->
        assert path =~ "/v1/graphql"
        assert body["query"] =~ "nearAudio"
        assert body["query"] =~ audio_data

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Podcast" => [
                 %{
                   "title" => "Tech Talk Episode 1",
                   "_additional" => %{"distance" => 0.2}
                 }
               ]
             }
           }
         }}
      end)

      assert {:ok, results} =
               QueryAdvanced.near_media(client, "Podcast", :audio, audio_data, limit: 5)

      assert is_list(results)
      assert length(results) == 1
      assert hd(results)["title"] == "Tech Talk Episode 1"
    end

    test "performs video similarity search", %{client: client} do
      video_data = "base64_video_data"

      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "nearVideo"
        assert body["query"] =~ video_data

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Video" => []
             }
           }
         }}
      end)

      assert {:ok, []} =
               QueryAdvanced.near_media(client, "Video", :video, video_data)
    end

    test "performs thermal similarity search (ImageBind)", %{client: client} do
      thermal_data = "base64_thermal_data"

      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "nearThermal"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "ThermalImage" => []
             }
           }
         }}
      end)

      assert {:ok, []} =
               QueryAdvanced.near_media(client, "ThermalImage", :thermal, thermal_data)
    end

    test "handles unsupported media type", %{client: client} do
      # This should fail validation before making request
      assert {:error, %WeaviateEx.Error{type: :validation_error}} =
               QueryAdvanced.near_media(client, "Media", :unsupported, "data")
    end
  end

  describe "sort/2" do
    test "adds single sort field to query", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "sort:"
        assert body["query"] =~ "title"
        assert body["query"] =~ "asc"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{"title" => "AAA Article"},
                 %{"title" => "BBB Article"}
               ]
             }
           }
         }}
      end)

      query = build_base_query()

      assert {:ok, results} =
               query
               |> QueryAdvanced.sort([{:title, :asc}])
               |> execute_query(client)

      assert length(results) == 2
    end

    test "adds multiple sort fields to query", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "sort:"
        # Should have both publishedAt desc and title asc
        assert body["query"] =~ "publishedAt"
        assert body["query"] =~ "desc"
        assert body["query"] =~ "title"
        assert body["query"] =~ "asc"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      query = build_base_query()

      assert {:ok, []} =
               query
               |> QueryAdvanced.sort([{:publishedAt, :desc}, {:title, :asc}])
               |> execute_query(client)
    end

    test "replaces existing sort when called multiple times", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        # Should only have the last sort (views desc)
        assert body["query"] =~ "views"
        assert body["query"] =~ "desc"
        # Check that title is not in the sort clause (only in fields)
        assert body["query"] =~ ~r/sort:.*views/
        refute body["query"] =~ ~r/sort:.*title/

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      query = build_base_query()

      assert {:ok, []} =
               query
               |> QueryAdvanced.sort([{:title, :asc}])
               |> QueryAdvanced.sort([{:views, :desc}])
               |> execute_query(client)
    end
  end

  describe "group_by/3" do
    test "groups results by property", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "groupBy"
        assert body["query"] =~ "category"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{
                   "category" => "technology",
                   "_additional" => %{
                     "group" => %{
                       "count" => 15,
                       "hits" => [
                         %{"title" => "Tech Article 1"},
                         %{"title" => "Tech Article 2"}
                       ]
                     }
                   }
                 }
               ]
             }
           }
         }}
      end)

      query = build_base_query()

      assert {:ok, results} =
               query
               |> QueryAdvanced.group_by("category", groups: 3, objects_per_group: 2)
               |> execute_query(client)

      assert length(results) > 0
    end

    test "groups results with path traversal", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "groupBy"
        # Nested path: author.name
        assert body["query"] =~ "author"
        assert body["query"] =~ "name"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      query = build_base_query()

      assert {:ok, []} =
               query
               |> QueryAdvanced.group_by("author.name")
               |> execute_query(client)
    end
  end

  describe "autocut/2" do
    test "adds autocut parameter to query", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "autocut"
        assert body["query"] =~ "5"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => [
                 %{"title" => "Highly Relevant Article 1"},
                 %{"title" => "Highly Relevant Article 2"}
               ]
             }
           }
         }}
      end)

      query = build_base_query()

      assert {:ok, results} =
               query
               |> QueryAdvanced.autocut(5)
               |> execute_query(client)

      assert length(results) == 2
    end

    test "autocut with near_text query", %{client: client} do
      Mox.expect(Mock, :request, fn _client, :post, _path, body, _opts ->
        assert body["query"] =~ "nearText"
        assert body["query"] =~ "autocut"

        {:ok,
         %{
           "data" => %{
             "Get" => %{
               "Article" => []
             }
           }
         }}
      end)

      # Simulate combining with near_text
      query =
        build_base_query()
        |> Map.put(:near_text, "artificial intelligence")
        |> QueryAdvanced.autocut(3)

      assert {:ok, []} = execute_query(query, client)
    end
  end

  ## Helper Functions

  defp build_base_query do
    %{
      collection: "Article",
      fields: ["title", "content"],
      limit: 10
    }
  end

  defp execute_query(query, client) do
    # Mock implementation - in real code this would call Query.execute/1
    # Build a GraphQL query string from the query map to test query builders
    collection = query.collection
    fields = Map.get(query, :fields, ["title"])
    _limit = Map.get(query, :limit, 10)

    # Build query parameters
    params = []

    # Add sort if present
    params =
      if sort_fields = Map.get(query, :sort) do
        sort_str = build_sort_string(sort_fields)
        ["sort: #{sort_str}" | params]
      else
        params
      end

    # Add groupBy if present
    params =
      if group_by = Map.get(query, :group_by) do
        group_str = build_group_by_string(group_by)
        ["groupBy: #{group_str}" | params]
      else
        params
      end

    # Add autocut if present
    params =
      if autocut = Map.get(query, :autocut) do
        ["autocut: #{autocut}" | params]
      else
        params
      end

    # Add nearText if present (for testing)
    params =
      if near_text = Map.get(query, :near_text) do
        ["nearText: { concepts: [\"#{near_text}\"] }" | params]
      else
        params
      end

    # Build full query
    params_str =
      if Enum.empty?(params) do
        ""
      else
        "(#{Enum.join(Enum.reverse(params), ", ")})"
      end

    graphql_query = """
    {
      Get {
        #{collection}#{params_str} {
          #{Enum.join(fields, "\n      ")}
        }
      }
    }
    """

    WeaviateEx.Client.request(client, :post, "/v1/graphql", %{"query" => graphql_query}, [])
    |> case do
      {:ok, %{"data" => %{"Get" => get_results}}} ->
        results = Map.get(get_results, collection, [])
        {:ok, results}

      {:ok, _} ->
        {:ok, []}

      error ->
        error
    end
  end

  defp build_sort_string(sort_fields) do
    sorts =
      Enum.map(sort_fields, fn %{path: path, order: order} ->
        "{ path: [\"#{Enum.join(path, "\", \"")}\"], order: #{order} }"
      end)

    "[#{Enum.join(sorts, ", ")}]"
  end

  defp build_group_by_string(group_by) do
    %{path: path, groups: groups, objects_per_group: objects} = group_by
    "{ path: [\"#{Enum.join(path, "\", \"")}\"], groups: #{groups}, objectsPerGroup: #{objects} }"
  end
end
