{
  description = "Asgard Homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (pkgs.lib.getName pkg) [ "1password-cli" ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Jsonnet
            jsonnet-bundler
            tanka

            # Kubernetes
            kubectl
            kubernetes-helm
            talosctl
            argocd
            argo-workflows

            # Task runners
            go-task

            # Utilities
            yq-go
            _1password-cli
          ];
        };
      }
    );
}
