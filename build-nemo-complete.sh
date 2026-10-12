#!/bin/bash
#
# build-nemo-complete.sh
#
# Builds a single "everything you need" installer .deb for the MyNemo fork:
# one package (nemo-complete) that bundles nemo, nemo-data, libnemo-extension1,
# libnemo-extension-dev and gir1.2-nemo-3.0 (the debug-symbol package is NOT
# included).
#
# Why this script exists
# ----------------------
# The menu / popup / .glade UI definitions are NOT compiled into /usr/bin/nemo:
# they live in a GResource that is linked into libnemo-extension.so.1.4.0.
# A combined package that bundles a freshly built nemo binary but a stale
# libnemo-extension.so silently shows OLD menus (this is exactly how the
# "Backup" context-menu item went missing). This script therefore always
# rebuilds the standard packages and merges the freshly built library.
#
# It relies on the local dependency prefix used to build Nemo on this machine
# (/home/niel/nemo-prefix). Override with NEMO_PREFIX=... if needed.
#
# Usage:   ./build-nemo-complete.sh
#
set -euo pipefail

VERSION="6.7.8"
ARCH="amd64"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEB_PARENT="$(dirname "$REPO_DIR")"
PREFIX_DIR="${NEMO_PREFIX:-/home/niel/nemo-prefix/usr}"

PKGS=(nemo nemo-data libnemo-extension1 libnemo-extension-dev gir1.2-nemo-3.0)
OUT="$REPO_DIR/nemo-complete_${VERSION}_${ARCH}.deb"
CONTROL_TEMPLATE="$REPO_DIR/packaging/nemo-complete.control"

# ---------------------------------------------------------------------------
# Build environment (mirrors the local nemo-prefix used to compile Nemo)
# ---------------------------------------------------------------------------
export PKG_CONFIG_PATH="${PREFIX_DIR}/lib/x86_64-linux-gnu/pkgconfig:${PREFIX_DIR}/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig"
export LD_LIBRARY_PATH="${PREFIX_DIR}/lib/x86_64-linux-gnu:${PREFIX_DIR}/lib:${LD_LIBRARY_PATH:-}"
export PATH="${PREFIX_DIR}/bin:${PREFIX_DIR}/lib/x86_64-linux-gnu/bin:${PATH}"
export C_INCLUDE_PATH="${PREFIX_DIR}/include:${PREFIX_DIR}/include/x86_64-linux-gnu:${C_INCLUDE_PATH:-}"
export CPLUS_INCLUDE_PATH="${PREFIX_DIR}/include:${PREFIX_DIR}/include/x86_64-linux-gnu:${CPLUS_INCLUDE_PATH:-}"
export LIBRARY_PATH="${PREFIX_DIR}/lib/x86_64-linux-gnu:${PREFIX_DIR}/lib:${LIBRARY_PATH:-}"
unset PKG_CONFIG_SYSROOT_DIR
export GI_TYPELIB_PATH="${PREFIX_DIR}/lib/x86_64-linux-gnu/gire:/usr/lib/x86_64-linux-gnu/gire:${GI_TYPELIB_PATH:-}"
export PYTHONPATH="${PREFIX_DIR}/lib/x86_64-linux-gnu/gobject-introspection:${PREFIX_DIR}/share/gtk-doc/python:${PYTHONPATH:-}"
export PERL5LIB="${PREFIX_DIR}/share/perl5:${PERL5LIB:-}"
export LDFLAGS="-L${PREFIX_DIR}/lib/x86_64-linux-gnu -L${PREFIX_DIR}/lib ${LDFLAGS:-}"
export DEB_BUILD_MAINT_OPTIONS="hardening=+bindnow"
export DEB_BUILD_OPTIONS="nocheck"
export DH_SHLIBDEPS="--ignore-missing-info"
export LC_ALL=C.UTF-8
export XML_CATALOG_FILES="${PREFIX_DIR}/share/xml/docbook/stylesheet/docbook-xsl/catalog.xml /etc/sgml/catalog"

# ---------------------------------------------------------------------------
# 1. Build the standard Debian packages
# ---------------------------------------------------------------------------
echo "==> Building standard packages (dpkg-buildpackage) ..."
( cd "$REPO_DIR" && dpkg-buildpackage --no-check-builddeps -b -uc -us -rfakeroot )

# ---------------------------------------------------------------------------
# 2. Merge the fresh packages into one combined package
# ---------------------------------------------------------------------------
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/root/DEBIAN"

echo "==> Merging packages into the combined installer ..."
for p in "${PKGS[@]}"; do
    deb="$(ls "$DEB_PARENT/${p}_${VERSION}"*.deb 2>/dev/null | head -1 || true)"
    if [ -z "$deb" ]; then
        echo "ERROR: expected package '$p' was not produced in $DEB_PARENT" >&2
        exit 1
    fi
    echo "    + $(basename "$deb")"
    dpkg-deb -x "$deb" "$STAGE/root"
done

# Sanity check: the library must actually contain the new UI definition.
LIB="$(ls "$STAGE"/root/usr/lib/*/libnemo-extension.so.*.* 2>/dev/null | head -1 || true)"
if [ -n "$LIB" ] && command -v python3 >/dev/null; then
    if ! python3 - "$LIB" <<'PY'
import sys
data = open(sys.argv[1], 'rb').read()
sys.exit(0 if b'<menuitem name="Backup" action="Backup"/>' in data else 1)
PY
    then
        echo "ERROR: bundled libnemo-extension.so does not contain the Backup menu item." >&2
        echo "       The UI resources are stale; aborting." >&2
        exit 1
    fi
fi

# Control file (Installed-Size is filled in automatically).
cp "$CONTROL_TEMPLATE" "$STAGE/root/DEBIAN/control"
sed -i "s/^Installed-Size:.*/Installed-Size: $(du -sk "$STAGE/root" | cut -f1)/" \
    "$STAGE/root/DEBIAN/control"

# ---------------------------------------------------------------------------
# 3. Produce the combined .deb
# ---------------------------------------------------------------------------
echo "==> Building $OUT ..."
dpkg-deb --build --root-owner-group "$STAGE/root" "$OUT"

# Remove the intermediate standard packages so only the combined one remains.
for p in "${PKGS[@]}" nemo-dbg; do
    rm -f "$DEB_PARENT/${p}_${VERSION}"*.deb
done
rm -f "$DEB_PARENT"/nemo_${VERSION}_${ARCH}.buildinfo "$DEB_PARENT"/nemo_${VERSION}_${ARCH}.changes

echo "==> Done: $OUT"
echo "    Install with:  sudo apt install \"$OUT\""
