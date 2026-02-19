defmodule ExScimClient.Model.Core.User do
  @moduledoc """
  SCIM User resource (core: urn:ietf:params:scim:schemas:core:2.0:User).
  """

  @derive JSON.Encoder
  defstruct [
    :schemas,
    :id,
    :externalId,
    :meta,
    :userName,
    :name,
    :displayName,
    :nickName,
    :profileUrl,
    :title,
    :userType,
    :preferredLanguage,
    :locale,
    :timezone,
    :active,
    :password,
    :emails,
    :phoneNumbers,
    :ims,
    :photos,
    :addresses,
    :entitlements,
    :roles,
    :x509Certificates,
    :groups,
    :"urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
  ]

  @type t :: %__MODULE__{
          :schemas => [String.t()],
          :id => String.t() | nil,
          :externalId => String.t() | nil,
          :meta => ExScimClient.Model.Infrastructure.Meta.t() | nil,
          :userName => String.t(),
          :name => ExScimClient.Model.UserAttributes.Name.t() | nil,
          :displayName => String.t() | nil,
          :nickName => String.t() | nil,
          :profileUrl => Uri | nil,
          :title => String.t() | nil,
          :userType => String.t() | nil,
          :preferredLanguage => String.t() | nil,
          :locale => String.t() | nil,
          :timezone => String.t() | nil,
          :active => boolean() | nil,
          :password => String.t() | nil,
          :emails => [ExScimClient.Model.UserAttributes.Email.t()] | nil,
          :phoneNumbers => [ExScimClient.Model.UserAttributes.PhoneNumber.t()] | nil,
          :ims => [ExScimClient.Model.UserAttributes.Im.t()] | nil,
          :photos => [ExScimClient.Model.UserAttributes.Photo.t()] | nil,
          :addresses => [ExScimClient.Model.UserAttributes.Address.t()] | nil,
          :entitlements => [ExScimClient.Model.UserAttributes.Entitlement.t()] | nil,
          :roles => [ExScimClient.Model.UserAttributes.Role.t()] | nil,
          :x509Certificates => [ExScimClient.Model.UserAttributes.X509Certificate.t()] | nil,
          :groups => [ExScimClient.Model.References.GroupMemberRef.t()] | nil,
          :"urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" =>
            ExScimClient.Model.UserAttributes.EnterpriseUser.t() | nil
        }

  alias ExScimClient.Deserializer

  @doc false
  def decode(value) do
    value
    |> Deserializer.deserialize(:meta, :struct, ExScimClient.Model.Infrastructure.Meta)
    |> Deserializer.deserialize(:name, :struct, ExScimClient.Model.UserAttributes.Name)
    |> Deserializer.deserialize(:profileUrl, :struct, ExScimClient.Model.Infrastructure.Uri)
    |> Deserializer.deserialize(:emails, :list, ExScimClient.Model.UserAttributes.Email)
    |> Deserializer.deserialize(
      :phoneNumbers,
      :list,
      ExScimClient.Model.UserAttributes.PhoneNumber
    )
    |> Deserializer.deserialize(:ims, :list, ExScimClient.Model.UserAttributes.Im)
    |> Deserializer.deserialize(:photos, :list, ExScimClient.Model.UserAttributes.Photo)
    |> Deserializer.deserialize(:addresses, :list, ExScimClient.Model.UserAttributes.Address)
    |> Deserializer.deserialize(
      :entitlements,
      :list,
      ExScimClient.Model.UserAttributes.Entitlement
    )
    |> Deserializer.deserialize(:roles, :list, ExScimClient.Model.UserAttributes.Role)
    |> Deserializer.deserialize(
      :x509Certificates,
      :list,
      ExScimClient.Model.UserAttributes.X509Certificate
    )
    |> Deserializer.deserialize(:groups, :list, ExScimClient.Model.References.GroupMemberRef)
    |> Deserializer.deserialize(
      :"urn:ietf:params:scim:schemas:extension:enterprise:2.0:User",
      :struct,
      ExScimClient.Model.UserAttributes.EnterpriseUser
    )
  end
end
