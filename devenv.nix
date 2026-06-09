{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  packages = [
    pkgs.git
    pkgs.inotify-tools
    pkgs.tailwindcss-language-server
    pkgs.tailwindcss_4
    pkgs.nodejs
    pkgs.vscode-langservers-extracted
    pkgs.prettier
    inputs.expert.packages.${pkgs.system}.default
  ];

  languages.elixir.enable = true;
  languages.elixir.package = pkgs.beam28Packages.elixir_1_20.overrideAttrs {
    version = "1.20.1";
    src = pkgs.fetchFromGitHub {
      owner = "elixir-lang";
      repo = "elixir";
      rev = "v1.20.1";
      hash = "sha256-eOYqYcZpHJqgbut0iOrey6CMD3LIvpqc3AU9L/g7a+Y=";
    };
  };
  languages.javascript.enable = true;

  env.TAILWINDCSS_PATH = "${pkgs.lib.getExe pkgs.tailwindcss_4}";

  git-hooks.hooks.mix-format.enable = true;
}
