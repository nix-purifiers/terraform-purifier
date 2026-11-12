# SPDX-License-Identifier: MIT
{
  lib,
  stdenv,
  runCommand,
  fetchurl,
  fetchgit,
  unzip,
  zstd,
  purifier,
}:
{
  lock,
  fetchers ? { },
}:
let
  checked = purifier.checkLock lock;
  missing = builtins.filter (
    address: !(builtins.elem stdenv.hostPlatform.system checked.providerSystems.${address})
  ) (builtins.attrNames checked.providerSystems);
in
assert
  missing == [ ]
  || throw "terraform-purifier: no locked provider download for ${stdenv.hostPlatform.system}: ${lib.concatStringsSep ", " missing}; run terraform-purifier lock --platform with this system's native platform";
purifier.tree (
  {
    name = "terraform-dependencies";
    entries = lib.filter (
      e: !(e ? systems) || builtins.elem stdenv.hostPlatform.system e.systems
    ) checked.entries;
    inherit
      runCommand
      fetchurl
      fetchgit
      unzip
      zstd
      ;
  }
  // fetchers
)
