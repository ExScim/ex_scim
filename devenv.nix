{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  packages = [ pkgs.git ];

  languages.elixir.enable = true;
  languages.elixir.package = pkgs.beam28Packages.elixir_1_19;

  git-hooks.hooks.mix-format.enable = true;
}
