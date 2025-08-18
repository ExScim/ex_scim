defmodule ExScimTest do
  use ExUnit.Case
  doctest ExScim

  test "provides version information" do
    version = ExScim.version()
    assert is_binary(version)
    assert String.length(version) > 0
  end
end
