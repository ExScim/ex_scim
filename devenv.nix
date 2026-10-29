{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.hostPlatform.system; };
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
    inputs.expert.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  languages = {
    elixir = {
      enable = true;
      package = pkgs-unstable.beam29Packages.elixir_1_20;
    };
    javascript.enable = true;
  };

  env.TAILWINDCSS_PATH = "${pkgs.lib.getExe pkgs.tailwindcss_4}";

  /*
    services.postgres = {
      enable = true;
      listen_addresses = "127.0.0.1";
      port = 5433;
      initialDatabases = [
        {
          name = "ex_scim_ecto_test";
          user = "postgres";
          pass = "postgres";
        }
      ];
    };
  */

  git-hooks.hooks.mix-format.enable = true;
}
