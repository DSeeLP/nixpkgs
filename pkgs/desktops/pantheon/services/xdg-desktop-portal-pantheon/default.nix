{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  meson,
  ninja,
  pkg-config,
  vala,
  wrapGAppsHook4,
  glib,
  granite7,
  gsettings-desktop-schemas,
  gtk4,
  pantheon-wayland,
  systemd,
  xorg,
}:

stdenv.mkDerivation rec {
  pname = "xdg-desktop-portal-pantheon";
  version = "8.0.3";

  src = fetchFromGitHub {
    owner = "elementary";
    repo = "portals";
    rev = version;
    sha256 = "sha256-UGQ5kteX/W3ncKzTXXmVL/aI0WC3eqpl5prdmj7lBD8=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    vala
    wrapGAppsHook4
  ];

  buildInputs = [
    glib
    granite7
    gsettings-desktop-schemas
    gtk4
    pantheon-wayland
    systemd
    xorg.libX11
  ];

  mesonFlags = [
    "-Dsystemduserunitdir=${placeholder "out"}/lib/systemd/user"
  ];

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = with lib; {
    description = "Backend implementation for xdg-desktop-portal for the Pantheon desktop environment";
    homepage = "https://github.com/elementary/portals";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    teams = [ teams.pantheon ];
  };
}
