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

  git-hooks.hooks.mix-format.enable = true;
}
