{
  lib,
  stdenv,
  fetchurl,
  autoconf,
  automake,
  libsndfile,
  libtool,
  pkg-config,
  libuuid,
}:

stdenv.mkDerivation rec {
  pname = "libgig";
  version = "4.5.0";

  src = fetchurl {
    url = "https://download.linuxsampler.org/packages/${pname}-${version}.tar.bz2";
    sha256 = "sha256-CHnSi5tjktpZhYJtvdjZyVeyoDKi8QGQUGrvLiLzxUo=";
  };

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    pkg-config
  ];

  buildInputs = [
    libsndfile
    libuuid
  ];

  preConfigure = "make -f Makefile.svn";

  enableParallelBuilding = true;

  meta = with lib; {
    homepage = "http://www.linuxsampler.org";
    description = "Gigasampler file access library";
    license = licenses.gpl2;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
