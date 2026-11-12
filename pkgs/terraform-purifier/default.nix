# SPDX-License-Identifier: MIT
{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  git,
  nix,
  nativeTool,
  terraform-ls,
  nix-prefetch-git,
  gh,
  cacert,
  nixpkgsSrc,
  purifierSrc,
}:
stdenvNoCC.mkDerivation {
  pname = "terraform-purifier";
  version = "0.1.0";
  src = ../..;
  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;
  installPhase = ''
    mkdir -p "$out/bin" "$out/lib/terraform-purifier"
    cp -r terraform_purifier nix lib-overlays pkgs "$out/lib/terraform-purifier/"
    install -m755 bin/terraform-purifier "$out/bin/terraform-purifier"
    substituteInPlace "$out/lib/terraform-purifier/nix/realize.nix" \
      --replace-fail '@nixpkgs@' '${nixpkgsSrc}' \
      --replace-fail '@purifier@' '${purifierSrc}' \
      --replace-fail '@runtime@' "$out"
    wrapProgram "$out/bin/terraform-purifier" \
      --prefix PATH : ${
        lib.makeBinPath [
          (python3.withPackages (p: [ p.python-hcl2 ]))
          git
          nix
          nativeTool
          nix-prefetch-git
          gh
        ]
      } \
      --prefix PYTHONPATH : "$out/lib/terraform-purifier" \
      --set TERRAFORM_PURIFIER_TOOL ${nativeTool}/bin/terraform \
      --set TERRAFORM_PURIFIER_TOOL_VERSION ${nativeTool.version} \
      --set TERRAFORM_PURIFIER_REALIZE "$out/lib/terraform-purifier/nix/realize.nix" \
      --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
    makeWrapper "$out/bin/terraform-purifier" "$out/bin/terraform" --add-flags "native --"
    ln -s ${terraform-ls}/bin/terraform-ls "$out/bin/terraform-ls"
  '';
  meta = {
    description = "Locked, Nix-resolved Terraform dependencies";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "terraform-purifier";
    homepage = "https://nix-purifiers.github.io/";
  };
}
