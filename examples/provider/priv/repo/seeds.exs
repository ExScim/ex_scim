# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Provider.Repo.insert!(%Provider.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Provider.Repo
alias Provider.Accounts.User
alias Provider.Accounts.Group

now = DateTime.utc_now()

groups =
  [
    %{
      display_name: "Example Group",
      description: "An example group containing user",
      external_id: "824502db-065d-43c0-86a2-ab9eba4877d0"
    }
  ]

users = [
  %{
    id: "263675ec-fb54-4229-add0-815d10532625",
    user_name: "scim_test_user",
    given_name: "SCIM",
    family_name: "Test User",
    display_name: "SCIM Test User",
    email: "scim.test@example.com",
    external_id: "scim_test_user"
  },
  %{
    user_name: "tessconnelly",
    given_name: "Annamarie",
    family_name: "Jacobi",
    display_name: "Ivan Will",
    email: "suzanne.connelly@opensource.suvera.dev",
    external_id: "82ce4717-0a19-4bf3-b45f-5d7798d469ca"
  },
  %{
    user_name: "julian92",
    given_name: "Julian",
    family_name: "Borer",
    display_name: "Julian Borer",
    email: "julian.borer@example.com",
    external_id: "1a2b3c4d-1111-2222-3333-444455556666"
  },
  %{
    user_name: "marian87",
    given_name: "Marian",
    family_name: "Schmitt",
    display_name: "Marian Schmitt",
    email: "marian.schmitt@example.org",
    external_id: "2f3e4d5c-7777-8888-9999-aabbccddeeff"
  },
  %{
    user_name: "carmen98",
    given_name: "Carmen",
    family_name: "Ortiz",
    display_name: "Carmen Ortiz",
    email: "carmen.ortiz@example.com",
    external_id: "cc97b788-b5f7-470f-8c58-bb3b1024d676"
  },
  %{
    user_name: "andrew_b",
    given_name: "Andrew",
    family_name: "Blick",
    display_name: "Andrew Blick",
    email: "andrew.blick@example.net",
    external_id: "def12345-9999-aaaa-bbbb-ccccddddeeee"
  },
  %{
    user_name: "leah.k",
    given_name: "Leah",
    family_name: "Kautzer",
    display_name: "Leah Kautzer",
    email: "leah.kautzer@example.org",
    external_id: "ab12cd34-5678-9def-0000-123456789abc"
  },
  %{
    user_name: "rafael_g",
    given_name: "Rafael",
    family_name: "Gleason",
    display_name: "Rafael Gleason",
    email: "rafael.gleason@example.com",
    external_id: "eeeeffff-1111-2222-3333-444455556677"
  },
  %{
    user_name: "yasmin12",
    given_name: "Yasmin",
    family_name: "Hoppe",
    display_name: "Yasmin Hoppe",
    email: "yasmin.hoppe@example.net",
    external_id: "55556666-7777-8888-9999-aaaabbbbcccc"
  },
  %{
    user_name: "roberto.f",
    given_name: "Roberto",
    family_name: "Fay",
    display_name: "Roberto Fay",
    email: "roberto.fay@example.com",
    external_id: "32143214-1111-1111-aaaa-eeeeeeeeeeee"
  },
  %{
    user_name: "violet_r",
    given_name: "Violet",
    family_name: "Reichert",
    display_name: "Violet Reichert",
    email: "violet.reichert@example.org",
    external_id: "66667777-8888-9999-aaaa-bbbbccccdddd"
  }
]

insert_resource = fn mapper, attrs ->
  resource_attrs =
    attrs
    |> Map.put(:active, true)
    |> Map.put(:meta_created, now)
    |> Map.put(:meta_last_modified, now)

  changeset = mapper.(resource_attrs)
  Repo.insert!(changeset)
end

user_changeset = fn attrs ->
  if Map.has_key?(attrs, :id) do
    # Use the provided ID
    %User{id: attrs.id}
    |> User.changeset(Map.delete(attrs, :id))
  else
    # Let Ecto generate the ID
    %User{}
    |> User.changeset(attrs)
  end
end

group_changeset = fn attrs -> Group.changeset(%Group{}, attrs) end

Enum.each(users, &insert_resource.(user_changeset, &1))
Enum.each(groups, &insert_resource.(group_changeset, &1))
