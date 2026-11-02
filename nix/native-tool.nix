# SPDX-License-Identifier: MIT
{ terraform }:
terraform.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./native-lockfile.patch ];
})
