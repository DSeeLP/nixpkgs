{
  lib,
  stdenv,
  fetchurl,
  CoreServices,
  nix-update-script,
}:
stdenv.mkDerivation rec {
  pname = "xmake";
  version = "2.9.9";
  src = fetchurl {
    url = "https://github.com/xmake-io/xmake/releases/download/v${version}/xmake-v${version}.tar.gz";
    hash = "sha256-6SUFuDvJd2KG6ucZ1YvOp/8ld6/hLLXMsnnIHn28cC0=";
  };

  buildInputs = lib.optional stdenv.hostPlatform.isDarwin CoreServices;

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = with lib; {
    description = "Cross-platform build utility based on Lua";
    homepage = "https://xmake.io";
    license = licenses.asl20;
    maintainers = with maintainers; [
      rewine
      rennsax
    ];
  };
}
