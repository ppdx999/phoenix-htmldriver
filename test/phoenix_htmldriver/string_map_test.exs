defmodule PhoenixHtmldriver.StringMapTest do
  use ExUnit.Case, async: true
  alias PhoenixHtmldriver.StringMap

  describe "new/1" do
    test "creates map from keyword list with atom keys" do
      map = StringMap.new(username: "alice", password: "secret")

      assert map == %{"username" => "alice", "password" => "secret"}
    end

    test "creates map from map with string keys" do
      map = StringMap.new(%{"email" => "test@example.com", "password" => "secret"})

      assert map == %{"email" => "test@example.com", "password" => "secret"}
    end

    test "creates map from mixed atom and string keys" do
      map = StringMap.new(%{"email" => "test@example.com", password: "secret"})

      assert map == %{"email" => "test@example.com", "password" => "secret"}
    end

    test "creates empty map from empty list" do
      map = StringMap.new([])

      assert map == %{}
    end

    test "creates empty map from empty map" do
      map = StringMap.new(%{})

      assert map == %{}
    end
  end

  describe "put/3" do
    test "puts value with atom key" do
      map = %{"name" => "Alice"}
      result = StringMap.put(map, :age, 25)

      assert result == %{"name" => "Alice", "age" => 25}
    end

    test "puts value with string key" do
      map = %{}
      result = StringMap.put(map, "email", "test@example.com")

      assert result == %{"email" => "test@example.com"}
    end

    test "overwrites existing value" do
      map = %{"username" => "alice"}
      result = StringMap.put(map, :username, "bob")

      assert result == %{"username" => "bob"}
    end
  end

  describe "get/3" do
    test "gets value with atom key" do
      map = %{"username" => "alice"}

      assert StringMap.get(map, :username) == "alice"
    end

    test "gets value with string key" do
      map = %{"username" => "alice"}

      assert StringMap.get(map, "username") == "alice"
    end

    test "returns default when key not found with atom" do
      map = %{"username" => "alice"}

      assert StringMap.get(map, :missing, "default") == "default"
    end

    test "returns default when key not found with string" do
      map = %{"username" => "alice"}

      assert StringMap.get(map, "missing", "default") == "default"
    end

    test "returns nil as default when key not found" do
      map = %{"username" => "alice"}

      assert StringMap.get(map, :missing) == nil
    end
  end

  describe "delete/2" do
    test "deletes key with atom" do
      map = %{"username" => "alice", "password" => "secret"}
      result = StringMap.delete(map, :password)

      assert result == %{"username" => "alice"}
    end

    test "deletes key with string" do
      map = %{"username" => "alice", "password" => "secret"}
      result = StringMap.delete(map, "password")

      assert result == %{"username" => "alice"}
    end

    test "returns unchanged map when key not found" do
      map = %{"username" => "alice"}
      result = StringMap.delete(map, :missing)

      assert result == %{"username" => "alice"}
    end
  end

  describe "merge/2" do
    test "merges with keyword list" do
      map = %{"username" => "alice"}
      result = StringMap.merge(map, password: "secret")

      assert result == %{"username" => "alice", "password" => "secret"}
    end

    test "merges with map with string keys" do
      map = %{"username" => "alice"}
      result = StringMap.merge(map, %{"email" => "alice@example.com"})

      assert result == %{"username" => "alice", "email" => "alice@example.com"}
    end

    test "merges with map with atom keys" do
      map = %{"username" => "alice"}
      result = StringMap.merge(map, %{email: "alice@example.com"})

      assert result == %{"username" => "alice", "email" => "alice@example.com"}
    end

    test "overwrites values from second map" do
      map = %{"username" => "alice", "email" => "old@example.com"}
      result = StringMap.merge(map, %{"email" => "new@example.com", "password" => "secret"})

      assert result == %{"username" => "alice", "email" => "new@example.com", "password" => "secret"}
    end

    test "merges empty map" do
      map = %{"username" => "alice"}
      result = StringMap.merge(map, %{})

      assert result == %{"username" => "alice"}
    end
  end
end
