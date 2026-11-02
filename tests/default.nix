# SPDX-License-Identifier: MIT
{ pkgs, self }:
let
  python = pkgs.python3.withPackages (p: [ p.python-hcl2 ]);
  fixture = ../examples/random;
  project = pkgs.terraform-purifier.buildTerraformProject { src = fixture; };
  externalSource = builtins.path {
    path = fixture;
    name = "terraform-external-source";
    filter =
      path: type:
      !(builtins.elem (baseNameOf path) [
        ".terraform.lock.hcl"
        "terraform-purifier.lock.json"
        ".terraform"
        ".terraform-purifier"
      ]);
  };
  external = pkgs.terraform-purifier.buildTerraformProject {
    src = externalSource;
    lockFile = fixture + "/terraform-purifier.lock.json";
    terraformLock = fixture + "/.terraform.lock.hcl";
  };
  parsed = pkgs.writeText "terraform-native-lock.json" (
    builtins.toJSON (
      import ../nix/provider-lock.nix { inherit (pkgs) lib; } (fixture + "/.terraform.lock.hcl")
    )
  );
  errorCheck =
    case:
    pkgs.runCommand "terraform-${case}"
      {
        nativeBuildInputs = [
          python
          pkgs.nix
        ];
        SOURCE = self;
        NIXPKGS_LIB = "${pkgs.path}/lib";
        PURIFIER = self.inputs.purifier;
        PYTHONPATH = self;
      }
      ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        python ${./eval-errors.py} ${case}
        touch "$out"
      '';
in
{
  environment = project.packages.configuration;
  offline = project.tests;
  release = project.release;
  editor =
    pkgs.runCommand "terraform-editor-offline"
      {
        nativeBuildInputs = [
          pkgs.terraform-purifier.nativeTool
          pkgs.terraform-ls
          pkgs.python3
        ];
      }
      ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        cp -r ${project.packages.configuration} work
        chmod -R u+w work
        cd work
        export TF_DATA_DIR="$PWD/.terraform" NIX_PURIFIER_NATIVE_LOCKFILE="$PWD/.terraform.lock.hcl"
        python ${./editor.py}
        touch "$out"
      '';
  conformance-external = external.tests;
  unit = pkgs.runCommand "terraform-unit" { nativeBuildInputs = [ python ]; } ''
    cp -r ${self} source
    chmod -R u+w source
    cd source
    python -m unittest discover -s tests -v
    python -c 'import json; from terraform_purifier.lock import providers; assert providers("examples/random/.terraform.lock.hcl") == json.load(open("${parsed}"))'
    touch "$out"
  '';
}
// pkgs.lib.genAttrs [
  "conformance-stale"
  "conformance-tampered"
  "conformance-missing"
  "conformance-malformed"
] (name: errorCheck (pkgs.lib.removePrefix "conformance-" name))
