defmodule ExScim.Parser.LexicalTest do
  use ExUnit.Case, async: true

  # ExScim.Parser.Lexical exposes combinator builders, not parsers. Wrap each in
  # a defparsec so they can be exercised directly.
  defmodule Helper do
    import NimbleParsec
    alias ExScim.Parser.Lexical

    defparsec(:alpha, Lexical.alpha())
    defparsec(:digit, Lexical.digit())
    defparsec(:hexdig, Lexical.hexdig())
    defparsec(:wsp, Lexical.wsp())
    defparsec(:quoted_string, Lexical.quoted_string())
    defparsec(:comp_keyword, Lexical.comp_keyword())
    defparsec(:comp_value, Lexical.comp_value())
  end

  describe "alpha/0" do
    test "matches a single letter and leaves the rest" do
      assert {:ok, ["a"], "bc", _, _, _} = Helper.alpha("abc")
    end

    test "rejects a non-letter" do
      assert {:error, _, _, _, _, _} = Helper.alpha("5")
    end
  end

  describe "digit/0" do
    test "matches a single digit" do
      assert {:ok, ["5"], "", _, _, _} = Helper.digit("5")
    end

    test "rejects a non-digit" do
      assert {:error, _, _, _, _, _} = Helper.digit("a")
    end
  end

  describe "hexdig/0" do
    test "matches digits and hex letters in both cases" do
      assert {:ok, ["9"], _, _, _, _} = Helper.hexdig("9")
      assert {:ok, ["F"], _, _, _, _} = Helper.hexdig("F")
      assert {:ok, ["a"], _, _, _, _} = Helper.hexdig("a")
    end

    test "rejects a non-hex letter" do
      assert {:error, _, _, _, _, _} = Helper.hexdig("g")
    end
  end

  describe "wsp/0" do
    test "consumes leading whitespace (space and tab)" do
      assert {:ok, _, "x", _, _, _} = Helper.wsp(" \tx")
    end

    test "succeeds with no whitespace (zero or more)" do
      assert {:ok, _, "x", _, _, _} = Helper.wsp("x")
    end
  end

  describe "quoted_string/0" do
    test "parses a quoted string and strips the quotes" do
      assert {:ok, ["hello"], "", _, _, _} = Helper.quoted_string(~s("hello"))
    end

    test "parses an empty quoted string" do
      assert {:ok, [""], "", _, _, _} = Helper.quoted_string(~s(""))
    end

    test "rejects an unterminated quoted string" do
      assert {:error, _, _, _, _, _} = Helper.quoted_string(~s("hello))
    end
  end

  describe "comp_keyword/0" do
    test "parses an alphanumeric keyword" do
      assert {:ok, ["active"], "", _, _, _} = Helper.comp_keyword("active")
    end

    test "allows digits, hyphens, and underscores after the first letter" do
      assert {:ok, ["a_b-1"], "", _, _, _} = Helper.comp_keyword("a_b-1")
    end

    test "rejects a leading digit" do
      assert {:error, _, _, _, _, _} = Helper.comp_keyword("1abc")
    end
  end

  describe "comp_value/0" do
    test "matches the boolean and null keywords" do
      assert {:ok, ["true"], "", _, _, _} = Helper.comp_value("true")
      assert {:ok, ["false"], "", _, _, _} = Helper.comp_value("false")
      assert {:ok, ["null"], "", _, _, _} = Helper.comp_value("null")
    end

    test "matches a quoted string value" do
      assert {:ok, ["work"], "", _, _, _} = Helper.comp_value(~s("work"))
    end

    test "falls back to a bare keyword value" do
      assert {:ok, ["active"], "", _, _, _} = Helper.comp_value("active")
    end
  end
end
