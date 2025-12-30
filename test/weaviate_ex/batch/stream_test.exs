defmodule WeaviateEx.Batch.StreamTest do
  use ExUnit.Case, async: true

  alias WeaviateEx.Batch.Stream

  describe "new/3" do
    test "creates new stream with default options" do
      client = %{grpc_channel: :fake_channel}

      {:ok, stream} = Stream.new(client, "TestCollection")

      assert stream.collection == "TestCollection"
      assert stream.buffer == []
      assert stream.buffer_size == 100
      assert stream.flush_interval_ms == 1000
      assert stream.server_side_batching == true
      assert stream.results == []
      assert stream.stream_handle == nil
      assert stream.state == :initialized
    end

    test "creates stream with custom buffer size" do
      client = %{grpc_channel: :fake_channel}

      {:ok, stream} = Stream.new(client, "TestCollection", buffer_size: 50)

      assert stream.buffer_size == 50
    end

    test "creates stream with custom flush interval" do
      client = %{grpc_channel: :fake_channel}

      {:ok, stream} = Stream.new(client, "TestCollection", flush_interval_ms: 2000)

      assert stream.flush_interval_ms == 2000
    end

    test "creates stream with server_side_batching disabled" do
      client = %{grpc_channel: :fake_channel}

      {:ok, stream} = Stream.new(client, "TestCollection", server_side_batching: false)

      assert stream.server_side_batching == false
    end

    test "creates stream with consistency level" do
      client = %{grpc_channel: :fake_channel}

      {:ok, stream} = Stream.new(client, "TestCollection", consistency_level: :all)

      assert stream.consistency_level == :all
    end

    test "returns error without gRPC channel" do
      client = %{grpc_channel: nil}

      assert {:error, :no_grpc_channel} = Stream.new(client, "TestCollection")
    end
  end

  describe "add/2" do
    setup do
      client = %{grpc_channel: :fake_channel}
      {:ok, stream} = Stream.new(client, "TestCollection")
      {:ok, stream: stream}
    end

    test "adds object to buffer", %{stream: stream} do
      object = %{uuid: "uuid-1", properties: %{"title" => "Test"}}

      {:ok, stream} = Stream.add(stream, object)

      assert length(stream.buffer) == 1
      assert hd(stream.buffer).uuid == "uuid-1"
    end

    test "adds object with auto-generated UUID", %{stream: stream} do
      object = %{properties: %{"title" => "Test"}}

      {:ok, stream} = Stream.add(stream, object)

      assert length(stream.buffer) == 1
      assert hd(stream.buffer).uuid != nil
    end

    test "adds collection to object if missing", %{stream: stream} do
      object = %{uuid: "uuid-1", properties: %{}}

      {:ok, stream} = Stream.add(stream, object)

      assert hd(stream.buffer).collection == "TestCollection"
    end

    test "preserves object's collection if specified", %{stream: stream} do
      object = %{uuid: "uuid-1", collection: "OtherCollection", properties: %{}}

      {:ok, stream} = Stream.add(stream, object)

      assert hd(stream.buffer).collection == "OtherCollection"
    end

    test "adds tenant to object if specified in stream", %{stream: stream} do
      stream = %{stream | tenant: "tenant-a"}
      object = %{uuid: "uuid-1", properties: %{}}

      {:ok, stream} = Stream.add(stream, object)

      assert hd(stream.buffer).tenant == "tenant-a"
    end
  end

  describe "add_many/2" do
    setup do
      client = %{grpc_channel: :fake_channel}
      {:ok, stream} = Stream.new(client, "TestCollection")
      {:ok, stream: stream}
    end

    test "adds multiple objects to buffer", %{stream: stream} do
      objects = [
        %{uuid: "uuid-1", properties: %{"title" => "Test 1"}},
        %{uuid: "uuid-2", properties: %{"title" => "Test 2"}},
        %{uuid: "uuid-3", properties: %{"title" => "Test 3"}}
      ]

      {:ok, stream} = Stream.add_many(stream, objects)

      assert length(stream.buffer) == 3
    end

    test "generates UUIDs for objects without them", %{stream: stream} do
      objects = [
        %{properties: %{"title" => "Test 1"}},
        %{properties: %{"title" => "Test 2"}}
      ]

      {:ok, stream} = Stream.add_many(stream, objects)

      assert Enum.all?(stream.buffer, fn obj -> obj.uuid != nil end)
    end

    test "handles empty list", %{stream: stream} do
      {:ok, stream} = Stream.add_many(stream, [])

      assert stream.buffer == []
    end
  end

  describe "buffer_full?/1" do
    setup do
      client = %{grpc_channel: :fake_channel}
      {:ok, stream} = Stream.new(client, "TestCollection", buffer_size: 3)
      {:ok, stream: stream}
    end

    test "returns false when buffer is not full", %{stream: stream} do
      stream = %{stream | buffer: [%{uuid: "1"}, %{uuid: "2"}]}

      refute Stream.buffer_full?(stream)
    end

    test "returns true when buffer reaches size", %{stream: stream} do
      stream = %{stream | buffer: [%{uuid: "1"}, %{uuid: "2"}, %{uuid: "3"}]}

      assert Stream.buffer_full?(stream)
    end

    test "returns true when buffer exceeds size", %{stream: stream} do
      stream = %{stream | buffer: [%{uuid: "1"}, %{uuid: "2"}, %{uuid: "3"}, %{uuid: "4"}]}

      assert Stream.buffer_full?(stream)
    end
  end

  describe "pending_count/1" do
    test "returns count of buffered objects" do
      stream = %Stream{buffer: [%{uuid: "1"}, %{uuid: "2"}, %{uuid: "3"}]}

      assert Stream.pending_count(stream) == 3
    end

    test "returns 0 for empty buffer" do
      stream = %Stream{buffer: []}

      assert Stream.pending_count(stream) == 0
    end
  end

  describe "results_count/1" do
    test "returns count of results" do
      stream = %Stream{
        results: [
          %{uuid: "1", status: :success},
          %{uuid: "2", status: :success}
        ]
      }

      assert Stream.results_count(stream) == 2
    end
  end

  describe "success_count/1" do
    test "counts successful results" do
      stream = %Stream{
        results: [
          %{uuid: "1", status: :success},
          %{uuid: "2", status: :error, error: "failed"},
          %{uuid: "3", status: :success}
        ]
      }

      assert Stream.success_count(stream) == 2
    end
  end

  describe "error_count/1" do
    test "counts error results" do
      stream = %Stream{
        results: [
          %{uuid: "1", status: :success},
          %{uuid: "2", status: :error, error: "failed"},
          %{uuid: "3", status: :error, error: "also failed"}
        ]
      }

      assert Stream.error_count(stream) == 2
    end
  end

  describe "get_errors/1" do
    test "returns only error results" do
      stream = %Stream{
        results: [
          %{uuid: "1", status: :success},
          %{uuid: "2", status: :error, error: "failed"},
          %{uuid: "3", status: :success},
          %{uuid: "4", status: :error, error: "also failed"}
        ]
      }

      errors = Stream.get_errors(stream)

      assert length(errors) == 2
      assert Enum.all?(errors, fn r -> r.status == :error end)
    end
  end

  describe "stream struct" do
    test "has all required fields" do
      stream = %Stream{}

      assert Map.has_key?(stream, :client)
      assert Map.has_key?(stream, :collection)
      assert Map.has_key?(stream, :stream_handle)
      assert Map.has_key?(stream, :buffer)
      assert Map.has_key?(stream, :buffer_size)
      assert Map.has_key?(stream, :results)
      assert Map.has_key?(stream, :state)
      assert Map.has_key?(stream, :flush_interval_ms)
      assert Map.has_key?(stream, :server_side_batching)
      assert Map.has_key?(stream, :consistency_level)
      assert Map.has_key?(stream, :tenant)
      assert Map.has_key?(stream, :last_flush_at)
      assert Map.has_key?(stream, :reconnect_attempts)
      assert Map.has_key?(stream, :max_reconnect_attempts)
    end

    test "has valid default state" do
      stream = %Stream{}

      assert stream.state == :initialized
      assert stream.buffer == []
      assert stream.results == []
      assert stream.buffer_size == 100
      assert stream.reconnect_attempts == 0
      assert stream.max_reconnect_attempts == 3
    end
  end

  describe "state transitions" do
    test "valid states" do
      assert Stream.valid_state?(:initialized)
      assert Stream.valid_state?(:connected)
      assert Stream.valid_state?(:streaming)
      assert Stream.valid_state?(:closing)
      assert Stream.valid_state?(:closed)
      assert Stream.valid_state?(:error)
      refute Stream.valid_state?(:invalid)
    end
  end

  describe "should_flush?/1" do
    test "returns true when buffer is full" do
      stream = %Stream{
        buffer: Enum.map(1..100, &%{uuid: "#{&1}"}),
        buffer_size: 100,
        last_flush_at: DateTime.utc_now()
      }

      assert Stream.should_flush?(stream)
    end

    test "returns true when flush interval exceeded" do
      past = DateTime.add(DateTime.utc_now(), -2, :second)

      stream = %Stream{
        buffer: [%{uuid: "1"}],
        buffer_size: 100,
        flush_interval_ms: 1000,
        last_flush_at: past
      }

      assert Stream.should_flush?(stream)
    end

    test "returns false when buffer not full and interval not exceeded" do
      stream = %Stream{
        buffer: [%{uuid: "1"}],
        buffer_size: 100,
        flush_interval_ms: 1000,
        last_flush_at: DateTime.utc_now()
      }

      refute Stream.should_flush?(stream)
    end

    test "returns false when buffer is empty" do
      stream = %Stream{
        buffer: [],
        buffer_size: 100,
        flush_interval_ms: 1000,
        last_flush_at: DateTime.add(DateTime.utc_now(), -10, :second)
      }

      refute Stream.should_flush?(stream)
    end
  end

  describe "prepare_object/2" do
    test "adds collection if not present" do
      stream = %Stream{collection: "TestCollection"}
      object = %{uuid: "uuid-1", properties: %{}}

      prepared = Stream.prepare_object(stream, object)

      assert prepared.collection == "TestCollection"
    end

    test "generates UUID if not present" do
      stream = %Stream{collection: "TestCollection"}
      object = %{properties: %{}}

      prepared = Stream.prepare_object(stream, object)

      assert prepared.uuid != nil
      assert String.length(prepared.uuid) == 36
    end

    test "adds tenant if stream has tenant" do
      stream = %Stream{collection: "TestCollection", tenant: "tenant-a"}
      object = %{uuid: "uuid-1", properties: %{}}

      prepared = Stream.prepare_object(stream, object)

      assert prepared.tenant == "tenant-a"
    end

    test "preserves existing UUID" do
      stream = %Stream{collection: "TestCollection"}
      object = %{uuid: "my-custom-uuid", properties: %{}}

      prepared = Stream.prepare_object(stream, object)

      assert prepared.uuid == "my-custom-uuid"
    end
  end

  describe "apply_backoff/2" do
    test "updates buffer size when backoff size is provided" do
      stream = %Stream{buffer_size: 100}

      updated = Stream.apply_backoff(stream, 25)

      assert updated.buffer_size == 25
    end

    test "keeps buffer size when backoff size is invalid" do
      stream = %Stream{buffer_size: 100}

      assert Stream.apply_backoff(stream, 0).buffer_size == 100
      assert Stream.apply_backoff(stream, -5).buffer_size == 100
    end
  end
end
