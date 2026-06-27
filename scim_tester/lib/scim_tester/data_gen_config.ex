defmodule ScimTester.DataGenConfig do
  @moduledoc """
  Configuration for test data generation.

  Supports three modes:
  - `:default` - fixed lists of names, titles, and `example.com` domain
  - `:custom` - user-provided lists and domain
  - `:random` - algorithmically generated plausible names via syllable combinations
  """

  @default_first_names ["John", "Jane", "Alice", "Bob", "Charlie", "Diana", "Eve", "Frank"]
  @default_last_names [
    "Smith",
    "Johnson",
    "Williams",
    "Brown",
    "Jones",
    "Garcia",
    "Miller",
    "Davis"
  ]
  @default_job_titles [
    "Software Engineer",
    "Product Manager",
    "Data Analyst",
    "Designer",
    "Developer",
    "Consultant",
    "Architect",
    "Manager"
  ]

  defstruct mode: :default,
            email_domain: "example.com",
            first_names: @default_first_names,
            last_names: @default_last_names,
            job_titles: @default_job_titles,
            url_domain: "example.com"

  @type t :: %__MODULE__{
          mode: :default | :custom | :random,
          email_domain: String.t(),
          first_names: [String.t()],
          last_names: [String.t()],
          job_titles: [String.t()],
          url_domain: String.t()
        }

  def default, do: %__MODULE__{}

  @doc """
  Applies a map of form params to the config, ignoring absent fields and
  rejecting blank scalar/list values so existing settings are preserved.
  """
  def apply_params(%__MODULE__{} = config, params) do
    config
    |> put_scalar(params, "mode", :mode, &String.to_existing_atom/1)
    |> put_scalar(params, "email_domain", :email_domain, & &1)
    |> put_scalar(params, "url_domain", :url_domain, & &1)
    |> put_list(params, "first_names", :first_names)
    |> put_list(params, "last_names", :last_names)
    |> put_list(params, "job_titles", :job_titles)
  end

  defp put_scalar(config, params, param_key, field, transform) do
    case Map.get(params, param_key) do
      nil -> config
      "" -> config
      value -> Map.put(config, field, transform.(value))
    end
  end

  defp put_list(config, params, param_key, field) do
    case Map.get(params, param_key) do
      nil ->
        config

      text ->
        case parse_comma_list(text) do
          [] -> config
          values -> Map.put(config, field, values)
        end
    end
  end

  defp parse_comma_list(text) when is_binary(text) do
    text
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # --- Name generation ---

  def random_first_name(%__MODULE__{mode: :random}), do: generate_syllable_name()
  def random_first_name(%__MODULE__{first_names: names}), do: Enum.random(names)

  def random_last_name(%__MODULE__{mode: :random}), do: generate_syllable_name()
  def random_last_name(%__MODULE__{last_names: names}), do: Enum.random(names)

  def random_job_title(%__MODULE__{mode: :random}), do: random_job_title_generated()

  def random_job_title(%__MODULE__{job_titles: titles}), do: Enum.random(titles)

  def random_email(%__MODULE__{} = config, first, last) do
    id = random_string(8)
    domain = config.email_domain

    "#{String.downcase(first)}.#{String.downcase(last)}#{id}@#{domain}"
  end

  def random_url(%__MODULE__{} = config, path) do
    "https://#{config.url_domain}/#{path}"
  end

  # --- Syllable-based name generation ---

  @consonants ~w(b c d f g h j k l m n p r s t v w z)
  @vowels ~w(a e i o u)
  @role_adjectives ~w(Senior Lead Principal Staff Associate Junior)
  @role_nouns ~w(Engineer Analyst Designer Strategist Coordinator Specialist Developer Planner)

  def generate_syllable_name do
    syllable_count = Enum.random(2..3)

    1..syllable_count
    |> Enum.map(fn _ -> Enum.random(@consonants) <> Enum.random(@vowels) end)
    |> Enum.join()
    |> String.capitalize()
  end

  defp random_job_title_generated do
    "#{Enum.random(@role_adjectives)} #{Enum.random(@role_nouns)}"
  end

  defp random_string(length) do
    chars = String.graphemes("abcdefghijklmnopqrstuvwxyz0123456789")

    1..length
    |> Enum.map(fn _ -> Enum.random(chars) end)
    |> Enum.join()
  end

  # --- Serialization for JS persistence ---

  def to_map(%__MODULE__{} = config) do
    %{
      "mode" => Atom.to_string(config.mode),
      "email_domain" => config.email_domain,
      "first_names" => config.first_names,
      "last_names" => config.last_names,
      "job_titles" => config.job_titles,
      "url_domain" => config.url_domain
    }
  end

  def from_map(nil), do: default()

  def from_map(map) when is_map(map) do
    mode =
      case Map.get(map, "mode", "default") do
        "custom" -> :custom
        "random" -> :random
        _ -> :default
      end

    defaults = default()

    %__MODULE__{
      mode: mode,
      email_domain: Map.get(map, "email_domain", defaults.email_domain),
      first_names: parse_list(Map.get(map, "first_names"), defaults.first_names),
      last_names: parse_list(Map.get(map, "last_names"), defaults.last_names),
      job_titles: parse_list(Map.get(map, "job_titles"), defaults.job_titles),
      url_domain: Map.get(map, "url_domain", defaults.url_domain)
    }
  end

  defp parse_list(val, default) when is_list(val) do
    filtered = Enum.filter(val, &(is_binary(&1) and String.trim(&1) != ""))
    if filtered == [], do: default, else: filtered
  end

  defp parse_list(_, default), do: default
end
