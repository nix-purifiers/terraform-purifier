# SPDX-License-Identifier: MIT
{
  project,
  lockFile,
  terraformLock,
  target,
}:
let
  pkgs = import (builtins.toPath "@nixpkgs@") {
    config.allowUnfreePredicate = p: (p.pname or "") == "terraform";
  };
  purifier = import (builtins.toPath "@purifier@/nix/lib") { inherit (pkgs) lib; };
  nativeTool = pkgs.callPackage ./native-tool.nix { };
  args = {
    src = /. + project;
    lockFile = /. + lockFile;
    terraformLock = /. + terraformLock;
  };
  result = pkgs.callPackage ./build-project.nix { inherit purifier nativeTool; } args;
  read = import ./read-lock.nix { inherit (pkgs) lib; } args;
  oldData = builtins.fromJSON (builtins.readFile lockFile);
  oldModules =
    assert
      oldData.version == 1
      &&
        oldData.contentHash
        == builtins.hashString "sha256" (builtins.toJSON (removeAttrs oldData [ "contentHash" ]));
    purifier.tree {
      name = "terraform-module-pins";
      entries = import ./module-entries.nix oldData.modules;
      inherit (pkgs) runCommand fetchgit;
    };
in
if target == "dependencies" then
  let
    checked = purifier.checkLock read;
  in
  assert
    checked.toolVersion == nativeTool.version
    || throw "terraform-purifier: lock needs tool version ${checked.toolVersion}, but this scope delivers ${nativeTool.version}; run terraform-purifier lock with the intended toolchain";
  pkgs.callPackage ./dependencies.nix { inherit purifier; } { lock = checked; }
else if target == "modules" then
  oldModules
else if target == "runtime" then
  pkgs.runCommand "terraform-runtime" { } ''ln -s @runtime@ "$out"''
else if target == "release" then
  result.release
else
  throw "terraform-purifier: unknown realization target ${target}"
