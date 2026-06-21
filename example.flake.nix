{
  description = "Мой рабочий проект на Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    mimo-jail.url = "github:QQ3646/mimo-jail-lib";
  };

  outputs = {
    self,
    nixpkgs,
    mimo-jail,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    my-project-agent = mimo-jail.lib.${system}.makeJailedMimocode {
      name = "mimocode-rust-project";

      extraPkgs = [
        pkgs.cargo
        pkgs.rustc
        pkgs.rustfmt
      ];

      extraReadonlyDirs = [
        "/etc/some-database-config"
      ];
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [
        my-project-agent
        pkgs.cargo
        pkgs.rustc
      ];
    };
  };
}
