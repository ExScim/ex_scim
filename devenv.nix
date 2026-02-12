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
    pkgs.nodePackages.vscode-langservers-extracted
    pkgs.nodePackages.prettier
  ];

  languages.elixir.enable = true;
  languages.elixir.package = pkgs.beam27Packages.elixir_1_19;
  languages.javascript.enable = true;

  env.TAILWINDCSS_PATH = "${pkgs.lib.getExe pkgs.tailwindcss_4}";

  git-hooks.hooks.mix-format.enable = true;
}
