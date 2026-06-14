{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };
in
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
  languages.elixir.package = pkgs-unstable.beam29Packages.elixir_1_20;

  languages.javascript.enable = true;

  env.TAILWINDCSS_PATH = "${pkgs.lib.getExe pkgs.tailwindcss_4}";

  git-hooks.hooks.mix-format.enable = true;
}
