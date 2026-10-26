# pin.sh -- sourced by the tools. The one Omega compiler omtex is built and checked with.
OMTEX_OMEGA_REPO=https://github.com/aien-dev/omega-mv.git
OMTEX_OMEGA_COMMIT=91b3c9326919faf1491e29ae9276929e8349b8c7
OMTEX_OMC_SHA256=189ada82e00bb440cb41351bd252cc68c54a1b1050051cc42a1df700081c3b54
: "${OMTEX_HOME:=$here}"
: "${OMC:=$OMTEX_HOME/build/omega-mv/seed/out/omc}"

# Fetch the pinned omega-mv commit (read-only use of its committed seed/out/omc) when OMC is absent.
omtex_fetch_omc() {
  d=$OMTEX_HOME/build/omega-mv
  if [ ! -d "$d/.git" ]; then
    git init -q "$d"
    git -C "$d" remote add origin "$OMTEX_OMEGA_REPO"
  fi
  git -C "$d" fetch -q --depth 1 origin "$OMTEX_OMEGA_COMMIT"
  git -C "$d" checkout -q --detach FETCH_HEAD
}

omtex_check_omc() {
  [ -x "$OMC" ] || omtex_fetch_omc
  got=$(sha256sum < "$OMC" | cut -d' ' -f1)
  if [ "$got" != "$OMTEX_OMC_SHA256" ]; then
    echo "omtex: $OMC has sha256 $got, pinned $OMTEX_OMC_SHA256; refusing" >&2
    exit 2
  fi
}
