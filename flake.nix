{
  description = "Reusable lib for using jailed MiMoCode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    llm-agents,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        mimo-pkg = llm-agents.packages.${system}.mimo-code;

        makeJailedMimocode = {
          name ? "jailed-mimocode",
          extraPkgs ? [],
          extraReadwriteDirs ? [],
          extraReadonlyDirs ? [],
          env ? {},
        }: let
          allPkgs = [pkgs.git pkgs.ripgrep pkgs.nodejs pkgs.bashInteractive pkgs.coreutils] ++ extraPkgs;
          binPath = pkgs.lib.makeBinPath allPkgs;

          rwArgs = builtins.concatStringsSep "\n" (map (d: ''BWRAP_ARGS+=(--bind "${d}" "${d}")'') extraReadwriteDirs);
          roArgs = builtins.concatStringsSep "\n" (map (d: ''BWRAP_ARGS+=(--ro-bind "${d}" "${d}")'') extraReadonlyDirs);
          envArgs = builtins.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (k: v: ''export ${k}="${v}"'') env);
        in
          pkgs.writeShellScriptBin name ''
            #!/usr/bin/env bash
            exec 2>> /tmp/mimocode-sandbox.log

            mkdir -p "$HOME/.config/mimocode" \
                     "$HOME/.local/share/mimocode" \
                     "$HOME/.local/state/mimocode"

            BWRAP_ARGS=(
              --ro-bind /nix/store /nix/store
              --ro-bind /etc /etc
              --proc /proc
              --dev /dev
              --tmpfs /tmp
              --symlink "${pkgs.bashInteractive}/bin/bash" /bin/sh
              --symlink "${pkgs.coreutils}/bin/env" /usr/bin/env
              --bind "$PWD" "$PWD"
              --chdir "$PWD"

              --bind "$HOME/.config/mimocode" "$HOME/.config/mimocode"
              --bind "$HOME/.local/share/mimocode" "$HOME/.local/share/mimocode"
              --bind "$HOME/.local/state/mimocode" "$HOME/.local/state/mimocode"

              --ro-bind-try /etc/localtime /etc/localtime  # Таймзона
              --unshare-all
              --share-net
              --new-session
              --die-with-parent
            )

            # Безопасный проброс гит-конфигов
            [ -f "$HOME/.gitconfig" ] && BWRAP_ARGS+=(--ro-bind "$HOME/.gitconfig" "$HOME/.gitconfig")
            [ -f "$HOME/.config/git/config" ] && BWRAP_ARGS+=(--ro-bind "$HOME/.config/git/config" "$HOME/.config/git/config")

            ${rwArgs}
            ${roArgs}

            ${envArgs}

            export PATH="${binPath}"

            MIMO_BIN="${mimo-pkg}/bin/mimocode"
            [ ! -f "$MIMO_BIN" ] && MIMO_BIN="${mimo-pkg}/bin/mimo-code"

            exec ${pkgs.bubblewrap}/bin/bwrap "''${BWRAP_ARGS[@]}" "$MIMO_BIN" "$@"
          '';
      in {
        lib = {
          inherit makeJailedMimocode;
        };

        packages.default = makeJailedMimocode {};
      }
    );
}
