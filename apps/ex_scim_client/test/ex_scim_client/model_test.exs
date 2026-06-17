defmodule ExScimClient.ModelTest do
  use ExUnit.Case, async: true

  alias ExScimClient.Deserializer

  alias ExScimClient.Model.Core.{Group, ResourceType, Schema, ServiceProviderConfig, User}
  alias ExScimClient.Model.Infrastructure.{AuthenticationScheme, Meta, SchemaAttribute, Uri}
  alias ExScimClient.Model.Operations.{PatchOperation, PatchOperationValue, PatchRequest}
  alias ExScimClient.Model.References.{GroupMemberRef, ManagerRef, MemberRef}
  alias ExScimClient.Model.Bulk.{BulkOperationResult, BulkResponse}
  alias ExScimClient.Model.UserAttributes.{Email, EnterpriseUser, Name, Photo}

  @models [
    ExScimClient.Model.Bulk.BulkOperation,
    ExScimClient.Model.Bulk.BulkOperationResult,
    ExScimClient.Model.Bulk.BulkRequest,
    ExScimClient.Model.Bulk.BulkResponse,
    ExScimClient.Model.Core.Group,
    ExScimClient.Model.Core.ResourceType,
    ExScimClient.Model.Core.Schema,
    ExScimClient.Model.Core.SchemaExtension,
    ExScimClient.Model.Core.ServiceProviderConfig,
    ExScimClient.Model.Core.User,
    ExScimClient.Model.Infrastructure.AuthenticationScheme,
    ExScimClient.Model.Infrastructure.Error,
    ExScimClient.Model.Infrastructure.Meta,
    ExScimClient.Model.Infrastructure.SchemaAttribute,
    ExScimClient.Model.Infrastructure.Uri,
    ExScimClient.Model.Operations.ListResponse,
    ExScimClient.Model.Operations.PatchOperation,
    ExScimClient.Model.Operations.PatchOperationValue,
    ExScimClient.Model.Operations.PatchRequest,
    ExScimClient.Model.Operations.SearchRequest,
    ExScimClient.Model.References.GroupMemberRef,
    ExScimClient.Model.References.ManagerRef,
    ExScimClient.Model.References.MemberRef,
    ExScimClient.Model.UserAttributes.Address,
    ExScimClient.Model.UserAttributes.Email,
    ExScimClient.Model.UserAttributes.EnterpriseUser,
    ExScimClient.Model.UserAttributes.Entitlement,
    ExScimClient.Model.UserAttributes.Im,
    ExScimClient.Model.UserAttributes.Name,
    ExScimClient.Model.UserAttributes.PhoneNumber,
    ExScimClient.Model.UserAttributes.Photo,
    ExScimClient.Model.UserAttributes.Role,
    ExScimClient.Model.UserAttributes.X509Certificate
  ]

  describe "every model" do
    for mod <- @models do
      @mod mod

      test "#{inspect(mod)} decode/1 accepts an empty struct and the struct JSON-encodes" do
        s = struct(@mod)
        # decode/1 runs the model's body (nil fields pass through nested deserializers)
        assert @mod.decode(s) |> is_struct()
        # @derive JSON.Encoder produces a valid JSON string
        assert is_binary(JSON.encode!(s))
      end
    end
  end

  describe "composite decoders deserialize nested values" do
    test "User decodes meta, name, and emails into structs" do
      json =
        ~s({"userName":"jdoe","name":{"givenName":"J"},"emails":[{"value":"a@b.com","type":"work"}],"meta":{"resourceType":"User","location":"https://x/Users/1"}})

      assert {:ok, %User{} = user} = Deserializer.json_decode(json, User)
      assert %Name{givenName: "J"} = user.name
      assert [%Email{value: "a@b.com", type: "work"}] = user.emails
      assert %Meta{} = user.meta
      # Meta.decode recursively turns the location string into a Uri struct
      assert %Uri{value: "https://x/Users/1"} = user.meta.location
    end

    test "Group decodes members into MemberRef structs with a Uri $ref" do
      json = ~s({"displayName":"Eng","members":[{"value":"u1","$ref":"https://x/Users/u1"}]})

      assert {:ok, %Group{} = group} = Deserializer.json_decode(json, Group)
      assert [%MemberRef{value: "u1"} = member] = group.members
      assert %Uri{value: "https://x/Users/u1"} = Map.get(member, :"$ref")
    end

    test "Uri.decode builds a struct from a string and passes other values through" do
      assert %Uri{value: "https://x"} = Uri.decode("https://x")
      assert Uri.decode(nil) == nil
    end

    test "PatchRequest decodes Operations into PatchOperation with a PatchOperationValue" do
      json =
        ~s({"Operations":[{"op":"replace","path":"displayName","value":{"foo":"bar"}}]})

      assert {:ok, %PatchRequest{} = pr} = Deserializer.json_decode(json, PatchRequest)
      assert [%PatchOperation{op: "replace"} = op] = Map.get(pr, :Operations)
      assert %PatchOperationValue{} = op.value
    end

    test "BulkResponse decodes Operations into BulkOperationResult with a Uri location" do
      json = ~s({"Operations":[{"method":"POST","status":"201","location":"https://x/Users/1"}]})

      assert {:ok, %BulkResponse{} = resp} = Deserializer.json_decode(json, BulkResponse)
      assert [%BulkOperationResult{status: "201"} = result] = Map.get(resp, :Operations)
      assert %Uri{value: "https://x/Users/1"} = result.location
    end

    test "ServiceProviderConfig decodes meta, documentationUri, and authenticationSchemes" do
      json =
        ~s({"documentationUri":"https://x/docs","meta":{"resourceType":"ServiceProviderConfig"},"authenticationSchemes":[{"name":"OAuth","specUri":"https://x/spec"}]})

      assert {:ok, %ServiceProviderConfig{} = spc} =
               Deserializer.json_decode(json, ServiceProviderConfig)

      assert %Uri{value: "https://x/docs"} = spc.documentationUri
      assert %Meta{} = spc.meta
      assert [%AuthenticationScheme{name: "OAuth"} = scheme] = spc.authenticationSchemes
      assert %Uri{value: "https://x/spec"} = scheme.specUri
    end

    test "ResourceType decodes meta and schemaExtensions" do
      json =
        ~s({"id":"User","schemaExtensions":[{"schema":"urn:ext","required":true}],"meta":{"resourceType":"ResourceType"}})

      assert {:ok, %ResourceType{} = rt} = Deserializer.json_decode(json, ResourceType)
      assert %Meta{} = rt.meta
      assert [%ExScimClient.Model.Core.SchemaExtension{schema: "urn:ext"}] = rt.schemaExtensions
    end

    test "Schema decodes attributes (with recursive subAttributes)" do
      json =
        ~s({"id":"urn:User","attributes":[{"name":"name","type":"complex","subAttributes":[{"name":"givenName","type":"string"}]}]})

      assert {:ok, %Schema{} = schema} = Deserializer.json_decode(json, Schema)
      assert [%SchemaAttribute{name: "name"} = attr] = schema.attributes
      assert [%SchemaAttribute{name: "givenName"}] = attr.subAttributes
    end

    test "EnterpriseUser decodes a manager ManagerRef" do
      json = ~s({"employeeNumber":"123","manager":{"value":"m1","$ref":"https://x/Users/m1"}})

      assert {:ok, %EnterpriseUser{} = eu} = Deserializer.json_decode(json, EnterpriseUser)
      assert %ManagerRef{value: "m1"} = eu.manager
      assert %Uri{} = Map.get(eu.manager, :"$ref")
    end

    test "GroupMemberRef and Photo decode a Uri-typed field" do
      assert {:ok, %GroupMemberRef{} = ref} =
               Deserializer.json_decode(
                 ~s({"value":"g1","$ref":"https://x/Groups/g1"}),
                 GroupMemberRef
               )

      assert %Uri{value: "https://x/Groups/g1"} = Map.get(ref, :"$ref")

      assert {:ok, %Photo{} = photo} =
               Deserializer.json_decode(~s({"value":"https://x/p.png","type":"photo"}), Photo)

      assert %Uri{value: "https://x/p.png"} = photo.value
    end
  end
end
