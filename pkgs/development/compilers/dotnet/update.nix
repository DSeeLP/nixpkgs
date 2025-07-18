{
  stdenvNoCC,
  lib,
  fetchurl,
  writeScript,
  nix,
  runtimeShell,
  curl,
  cacert,
  jq,
  yq,
  gnupg,

  releaseManifestFile,
  releaseInfoFile,
  bootstrapSdkFile,
  allowPrerelease,
}:

let
  inherit (lib.importJSON releaseManifestFile) channel tag;

  pkg = stdenvNoCC.mkDerivation {
    name = "update-dotnet-vmr-env";

    nativeBuildInputs = [
      nix
      curl
      cacert
      jq
      yq
      gnupg
    ];
  };

  releaseKey = fetchurl {
    url = "https://dotnet.microsoft.com/download/dotnet/release-key-2023.asc";
    hash = "sha256-F668QB55md0GQvoG0jeA66Fb2RbrsRhFTzTbXIX3GUo=";
  };

  drv = builtins.unsafeDiscardOutputDependency pkg.drvPath;

  toOutputPath =
    path:
    let
      root = ../../../..;
    in
    lib.path.removePrefix root path;

in
writeScript "update-dotnet-vmr.sh" ''
  #! ${nix}/bin/nix-shell
  #! nix-shell -i ${runtimeShell} --pure ${drv} --keep UPDATE_NIX_ATTR_PATH
  set -euo pipefail

  tag=''${1-}

  if [[ -n $tag ]]; then
      query=$(cat <<EOF
          map(
              select(
                  (.tag_name == "$tag"))) |
          first
  EOF
      )
  else
      query=$(cat <<EOF
          map(
              select(
                  ${lib.optionalString (!allowPrerelease) ".prerelease == false and"}
                  .draft == false and
                  (.tag_name | startswith("v${channel}")))) |
          first
  EOF
      )
  fi

  query="$query "$(cat <<EOF
      | (
          .tag_name,
          (.assets |
              .[] |
              select(.name == "release.json") |
              .browser_download_url),
          (.assets |
              .[] |
              select(.name | endswith(".tar.gz.sig")) |
              .browser_download_url))
  EOF
  )

  (
      curl -fsSL https://api.github.com/repos/dotnet/dotnet/releases | \
      jq -er "$query" \
  ) | (
      read tagName
      read releaseUrl
      read sigUrl

      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT

      cd "$tmp"

      curl -fsSL "$releaseUrl" -o release.json

      if [[ -z $tag && "$tagName" == "${tag}" ]]; then
          >&2 echo "release is already $tagName"
          exit
      fi

      tarballUrl=https://github.com/dotnet/dotnet/archive/refs/tags/$tagName.tar.gz

      mapfile -t prefetch < <(nix-prefetch-url --print-path "$tarballUrl")
      tarballHash=$(nix-hash --to-sri --type sha256 "''${prefetch[0]}")
      tarball=''${prefetch[1]}

      curl -fssL "$sigUrl" -o release.sig

      (
          export GNUPGHOME=$PWD/.gnupg
          trap 'gpgconf --kill all' EXIT
          gpg --batch --import ${releaseKey}
          gpg --batch --verify release.sig "$tarball"
      )

      tar --strip-components=1 --no-wildcards-match-slash --wildcards -xzf "$tarball" \*/eng/Versions.props \*/global.json
      artifactsVersion=$(xq -r '.Project.PropertyGroup |
          map(select(.PrivateSourceBuiltArtifactsVersion))
          | .[] | .PrivateSourceBuiltArtifactsVersion' eng/Versions.props)

      if [[ "$artifactsVersion" != "" ]]; then
          artifactsUrl=https://builds.dotnet.microsoft.com/source-built-artifacts/assets/Private.SourceBuilt.Artifacts.$artifactsVersion.centos.9-x64.tar.gz
      else
          artifactsUrl=$(xq -r '.Project.PropertyGroup |
              map(select(.PrivateSourceBuiltArtifactsUrl))
              | .[] | .PrivateSourceBuiltArtifactsUrl' eng/Versions.props)
      fi
      artifactsUrl="''${artifactsUrl/dotnetcli.azureedge.net/builds.dotnet.microsoft.com}"

      artifactsHash=$(nix-hash --to-sri --type sha256 "$(nix-prefetch-url "$artifactsUrl")")

      sdkVersion=$(jq -er .tools.dotnet global.json)

      # below needs to be run in nixpkgs because toOutputPath uses relative paths
      cd -

      cp "$tmp"/release.json "${toOutputPath releaseManifestFile}"

      jq --null-input \
          --arg _0 "$tarballHash" \
          --arg _1 "$artifactsUrl" \
          --arg _2 "$artifactsHash" \
          '{
              "tarballHash": $_0,
              "artifactsUrl": $_1,
              "artifactsHash": $_2,
          }' > "${toOutputPath releaseInfoFile}"

      updateSDK() {
          ${lib.escapeShellArg (toOutputPath ./update.sh)} \
              -o ${lib.escapeShellArg (toOutputPath bootstrapSdkFile)} --sdk "$1" >&2
      }

      updateSDK "$sdkVersion" || if [[ $? == 2 ]]; then
          >&2 echo "WARNING: bootstrap sdk missing, attempting to bootstrap with self"
          updateSDK "$(jq -er .sdkVersion "$tmp"/release.json)"
      else
          exit 1
      fi

      $(nix-build -A $UPDATE_NIX_ATTR_PATH.fetch-deps --no-out-link) >&2
  )
''
