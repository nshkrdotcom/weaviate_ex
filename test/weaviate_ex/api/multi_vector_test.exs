defmodule WeaviateEx.API.MultiVectorTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.API.MultiVector

  describe "muvera_encoding/1" do
    test "creates default muvera encoding" do
      encoding = MultiVector.muvera_encoding()

      assert encoding == %{"muvera" => %{"enabled" => true}}
    end

    test "creates muvera encoding with ksim" do
      encoding = MultiVector.muvera_encoding(ksim: 64)

      assert encoding == %{"muvera" => %{"enabled" => true, "ksim" => 64}}
    end

    test "creates muvera encoding with dprojections" do
      encoding = MultiVector.muvera_encoding(dprojections: 128)

      assert encoding == %{"muvera" => %{"enabled" => true, "dprojections" => 128}}
    end

    test "creates muvera encoding with all options" do
      encoding = MultiVector.muvera_encoding(ksim: 64, dprojections: 128, repetitions: 4)

      assert encoding == %{
               "muvera" => %{
                 "enabled" => true,
                 "ksim" => 64,
                 "dprojections" => 128,
                 "repetitions" => 4
               }
             }
    end
  end

  describe "multi_vector_config/1" do
    test "creates empty config with no options" do
      config = MultiVector.multi_vector_config()

      assert config == %{}
    end

    test "creates config with max_sim aggregation" do
      config = MultiVector.multi_vector_config(aggregation: :max_sim)

      assert config == %{"aggregation" => "maxSim"}
    end

    test "creates config with string aggregation" do
      config = MultiVector.multi_vector_config(aggregation: "customAgg")

      assert config == %{"aggregation" => "customAgg"}
    end
  end

  describe "self_provided/1" do
    test "creates self-provided multi-vector config" do
      config = MultiVector.self_provided(name: "custom_multivec")

      assert config["name"] == "custom_multivec"
      assert config["vectorizer"] == %{"none" => %{}}
      assert config["vectorIndexType"] == "hnsw"
      assert is_map(config["vectorIndexConfig"])
    end

    test "creates self-provided with encoding" do
      encoding = MultiVector.muvera_encoding(ksim: 64)
      config = MultiVector.self_provided(name: "custom_multivec", encoding: encoding)

      assert config["name"] == "custom_multivec"
      assert config["vectorIndexConfig"]["multivector"]["muvera"]["ksim"] == 64
    end

    test "creates self-provided with multi_vector_config" do
      mv_config = MultiVector.multi_vector_config(aggregation: :max_sim)
      config = MultiVector.self_provided(name: "custom_multivec", multi_vector_config: mv_config)

      assert config["vectorIndexConfig"]["multivector"]["aggregation"] == "maxSim"
    end
  end

  describe "text2colbert_jinaai/1" do
    test "creates text2colbert-jinaai config with name" do
      config = MultiVector.text2colbert_jinaai(name: "colbert_vector")

      assert config["name"] == "colbert_vector"
      assert Map.has_key?(config["vectorizer"], "text2colbert-jinaai")
      assert config["vectorIndexType"] == "hnsw"
    end

    test "creates text2colbert-jinaai with model" do
      config = MultiVector.text2colbert_jinaai(name: "colbert_vector", model: "jina-colbert-v2")

      vectorizer_config = config["vectorizer"]["text2colbert-jinaai"]
      assert vectorizer_config["model"] == "jina-colbert-v2"
    end

    test "creates text2colbert-jinaai with dimensions" do
      config = MultiVector.text2colbert_jinaai(name: "colbert_vector", dimensions: 128)

      vectorizer_config = config["vectorizer"]["text2colbert-jinaai"]
      assert vectorizer_config["dimensions"] == 128
    end

    test "creates text2colbert-jinaai with source_properties" do
      config =
        MultiVector.text2colbert_jinaai(
          name: "colbert_vector",
          source_properties: ["title", "content"]
        )

      vectorizer_config = config["vectorizer"]["text2colbert-jinaai"]
      assert vectorizer_config["properties"] == ["title", "content"]
    end

    test "creates text2colbert-jinaai with encoding" do
      encoding = MultiVector.muvera_encoding(ksim: 64, dprojections: 128)

      config =
        MultiVector.text2colbert_jinaai(
          name: "colbert_vector",
          model: "jina-colbert-v2",
          encoding: encoding
        )

      assert config["vectorIndexConfig"]["multivector"]["muvera"]["ksim"] == 64
      assert config["vectorIndexConfig"]["multivector"]["muvera"]["dprojections"] == 128
    end

    test "creates text2colbert-jinaai with full configuration" do
      encoding = MultiVector.muvera_encoding(ksim: 64, dprojections: 128)
      mv_config = MultiVector.multi_vector_config(aggregation: :max_sim)

      config =
        MultiVector.text2colbert_jinaai(
          name: "colbert_vector",
          model: "jina-colbert-v2",
          source_properties: ["title", "content"],
          encoding: encoding,
          multi_vector_config: mv_config
        )

      assert config["name"] == "colbert_vector"
      assert config["vectorizer"]["text2colbert-jinaai"]["model"] == "jina-colbert-v2"
      assert config["vectorizer"]["text2colbert-jinaai"]["properties"] == ["title", "content"]
      assert config["vectorIndexConfig"]["multivector"]["aggregation"] == "maxSim"
      assert config["vectorIndexConfig"]["multivector"]["muvera"]["ksim"] == 64
    end
  end

  describe "multi2multivec_jinaai/1" do
    test "creates multi2multivec-jinaai config" do
      config = MultiVector.multi2multivec_jinaai(name: "multivec")

      assert config["name"] == "multivec"
      assert Map.has_key?(config["vectorizer"], "multi2multivec-jinaai")
    end

    test "creates multi2multivec-jinaai with model and fields" do
      config =
        MultiVector.multi2multivec_jinaai(
          name: "multivec",
          model: "jina-clip-v2",
          image_fields: ["image"],
          text_fields: ["caption"]
        )

      vectorizer_config = config["vectorizer"]["multi2multivec-jinaai"]
      assert vectorizer_config["model"] == "jina-clip-v2"
      assert vectorizer_config["imageFields"] == [%{"name" => "image"}]
      assert vectorizer_config["textFields"] == [%{"name" => "caption"}]
    end
  end
end
