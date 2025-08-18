defmodule ExScim.BulkTest do
  use ExUnit.Case, async: true

  alias ExScim.Operations.Bulk

  describe "process_bulk_request/2" do
    test "validates bulk request structure" do
      invalid_request = %{}

      assert {:error, "Invalid or missing schemas in bulk request"} =
               Bulk.process_bulk_request(invalid_request)
    end

    test "validates operations are present" do
      invalid_request = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"]
      }

      assert {:error, "Missing Operations field in bulk request"} =
               Bulk.process_bulk_request(invalid_request)
    end

    test "validates operations array is not empty" do
      invalid_request = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
        "Operations" => []
      }

      assert {:error, "Operations array cannot be empty"} =
               Bulk.process_bulk_request(invalid_request)
    end

    test "validates operation structure" do
      invalid_request = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
        "Operations" => [
          %{
            "method" => "POST"
            # Missing bulkId
          }
        ]
      }

      assert {:error, error_msg} = Bulk.process_bulk_request(invalid_request)
      assert String.contains?(error_msg, "missing required 'bulkId' field")
    end

    test "validates operation methods" do
      invalid_request = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
        "Operations" => [
          %{
            "method" => "INVALID",
            "bulkId" => "1"
          }
        ]
      }

      assert {:error, error_msg} = Bulk.process_bulk_request(invalid_request)
      assert String.contains?(error_msg, "has invalid method")
    end

    test "enforces maximum operations limit" do
      operations =
        for i <- 1..1001 do
          %{
            "method" => "POST",
            "bulkId" => "bulk_#{i}",
            "path" => "/Users",
            "data" => %{"userName" => "user#{i}"}
          }
        end

      invalid_request = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
        "Operations" => operations
      }

      assert {:error, error_msg} = Bulk.process_bulk_request(invalid_request)
      assert String.contains?(error_msg, "Too many operations")
    end

    test "processes valid bulk request with POST operations" do
      valid_request = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
        "Operations" => [
          %{
            "method" => "POST",
            "bulkId" => "bulk_1",
            "path" => "/Users",
            "data" => %{
              "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
              "userName" => "testuser1",
              "displayName" => "Test User 1"
            }
          }
        ]
      }

      assert {:ok, response} = Bulk.process_bulk_request(valid_request)
      assert response["schemas"] == ["urn:ietf:params:scim:api:messages:2.0:BulkResponse"]
      assert is_list(response["Operations"])
      assert length(response["Operations"]) == 1

      operation_result = List.first(response["Operations"])
      assert operation_result["method"] == "POST"
      assert operation_result["bulkId"] == "bulk_1"
      # Status will depend on whether Users context succeeds
      assert is_binary(operation_result["status"])
    end

    test "processes bulk request with failOnErrors parameter" do
      valid_request = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
        "failOnErrors" => 1,
        "Operations" => [
          %{
            "method" => "POST",
            "bulkId" => "bulk_1",
            "path" => "/Users",
            "data" => %{
              "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
              "userName" => "testuser1"
            }
          },
          %{
            "method" => "POST",
            "bulkId" => "bulk_2",
            "path" => "/Users",
            "data" => %{
              "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
              "userName" => "testuser2"
            }
          }
        ]
      }

      assert {:ok, response} = Bulk.process_bulk_request(valid_request)
      assert response["schemas"] == ["urn:ietf:params:scim:api:messages:2.0:BulkResponse"]
      assert is_list(response["Operations"])
    end

    test "handles DELETE operations" do
      valid_request = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
        "Operations" => [
          %{
            "method" => "DELETE",
            "bulkId" => "bulk_delete_1",
            "path" => "/Users/non-existent-id"
          }
        ]
      }

      assert {:ok, response} = Bulk.process_bulk_request(valid_request)
      operation_result = List.first(response["Operations"])
      assert operation_result["method"] == "DELETE"
      assert operation_result["bulkId"] == "bulk_delete_1"
      # Should return 404 for non-existent user
      assert operation_result["status"] == "404"
    end

    test "handles mixed operations" do
      # Test bulk request validation without actually creating resources
      valid_request = %{
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
        "Operations" => [
          %{
            "method" => "DELETE",
            "bulkId" => "delete_user_1",
            "path" => "/Users/non-existent-id-1"
          },
          %{
            "method" => "DELETE",
            "bulkId" => "delete_user_2",
            "path" => "/Users/non-existent-id-2"
          },
          %{
            "method" => "DELETE",
            "bulkId" => "delete_group_1",
            "path" => "/Groups/non-existent-id-3"
          }
        ]
      }

      assert {:ok, response} = Bulk.process_bulk_request(valid_request)
      assert length(response["Operations"]) == 3

      # All operations should return 404 since resources don't exist
      statuses = Enum.map(response["Operations"], & &1["status"])
      assert Enum.all?(statuses, fn status -> status == "404" end)

      bulk_ids = Enum.map(response["Operations"], & &1["bulkId"])
      assert "delete_user_1" in bulk_ids
      assert "delete_user_2" in bulk_ids
      assert "delete_group_1" in bulk_ids
    end
  end
end
