defmodule WeaviateEx.Generative.ParametersTest do
  @moduledoc """
  Tests for generative query parameters with multimodal support.
  """

  use ExUnit.Case, async: true

  alias WeaviateEx.Generative.Parameters

  describe "SinglePrompt" do
    test "creates with basic prompt" do
      param = Parameters.single_prompt("Summarize this article")

      assert %Parameters.SinglePrompt{} = param
      assert param.prompt == "Summarize this article"
      assert param.metadata == false
      assert param.debug == false
    end

    test "creates with all options" do
      param =
        Parameters.single_prompt("Describe the image",
          metadata: true,
          debug: true,
          image_properties: ["product_image"],
          non_blob_properties: ["name", "description"]
        )

      assert param.prompt == "Describe the image"
      assert param.metadata == true
      assert param.debug == true
      assert param.image_properties == ["product_image"]
      assert param.non_blob_properties == ["name", "description"]
    end

    test "creates with external images" do
      param =
        Parameters.single_prompt("What's in this image?",
          images: ["base64encodeddata123"]
        )

      assert param.images == ["base64encodeddata123"]
    end

    test "converts to graphql clause" do
      param =
        Parameters.single_prompt("Summarize {title}",
          metadata: true,
          debug: true
        )

      clause = Parameters.to_graphql_clause(param)

      assert clause =~ "singleResult"
      assert clause =~ "Summarize {title}"
      # Note: metadata and debug are query-level options, not part of the prompt clause
    end
  end

  describe "GroupedTask" do
    test "creates with basic prompt" do
      param = Parameters.grouped_task("Summarize all articles")

      assert %Parameters.GroupedTask{} = param
      assert param.prompt == "Summarize all articles"
      assert param.metadata == false
    end

    test "creates with multimodal options" do
      param =
        Parameters.grouped_task("Compare these products",
          image_properties: ["thumbnail", "main_image"],
          non_blob_properties: ["name", "price"],
          metadata: true
        )

      assert param.image_properties == ["thumbnail", "main_image"]
      assert param.non_blob_properties == ["name", "price"]
    end

    test "converts to graphql clause" do
      param = Parameters.grouped_task("Summarize: {content}")

      clause = Parameters.to_graphql_clause(param)

      assert clause =~ "groupedResult"
      assert clause =~ "Summarize: {content}"
    end
  end

  describe "image handling" do
    test "handles base64 images" do
      param =
        Parameters.single_prompt("Describe",
          images: ["data:image/png;base64,abc123"]
        )

      assert param.images == ["data:image/png;base64,abc123"]
    end

    test "handles multiple images" do
      param =
        Parameters.single_prompt("Compare",
          images: ["image1_base64", "image2_base64"]
        )

      assert length(param.images) == 2
    end
  end

  describe "to_query_options/1" do
    test "extracts metadata and debug options from single prompt" do
      param =
        Parameters.single_prompt("Test",
          metadata: true,
          debug: true
        )

      opts = Parameters.to_query_options(param)

      assert opts[:metadata] == true
      assert opts[:debug] == true
    end

    test "extracts image properties from grouped task" do
      param =
        Parameters.grouped_task("Test",
          image_properties: ["img"],
          non_blob_properties: ["text"]
        )

      opts = Parameters.to_query_options(param)

      assert opts[:image_properties] == ["img"]
      assert opts[:non_blob_properties] == ["text"]
    end
  end
end
