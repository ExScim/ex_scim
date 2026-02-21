# ExScimClient

HTTP client for consuming SCIM APIs.

## Installation

Add `ex_scim_client` to your dependencies:

```elixir
def deps do
  [
    {:ex_scim_client, "~> 0.1"}
  ]
end
```

## Usage

Create a client and perform operations:

```elixir
# Create client
client = ExScimClient.Client.new("https://scim.example.com/v2", "bearer_token")

# User operations
{:ok, user} = ExScimClient.Resources.Users.get(client, "user-123")
{:ok, users} = ExScimClient.Resources.Users.list(client)
{:ok, user} = ExScimClient.Resources.Users.create(client, %{userName: "jdoe"})

# Group operations
{:ok, groups} = ExScimClient.Resources.Groups.list(client)
{:ok, group} = ExScimClient.Resources.Groups.create(client, %{displayName: "Admins"})

# Filtering and pagination
filter = ExScimClient.Filter.new() |> ExScimClient.Filter.equals("active", "true")
pagination = ExScimClient.Pagination.new(50, 101)
{:ok, users} = ExScimClient.Resources.Users.list(client, filter: filter, pagination: pagination)

# Schema discovery
{:ok, schemas} = ExScimClient.Resources.Schemas.list(client)
{:ok, user_schema} = ExScimClient.Resources.Schemas.user_schema(client)
```