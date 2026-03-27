defmodule DocTestsTest do
  use ExUnit.Case

  doctest ExScimClient.Client
  doctest ExScimClient.Filter
  doctest ExScimClient.Pagination
  doctest ExScimClient.Sorting
end
