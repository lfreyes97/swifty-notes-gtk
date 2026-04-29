#!/usr/bin/env bash
# Verify the bundled hunspell dictionaries inside a freshly built
# Flatpak. Catches regressions when bumping the LibreOffice/dictionaries
# pin or editing the install list in the manifest — without this, a
# silently dropped dict or an upstream rename would only surface when
# end users complain that their language is missing.
#
# Usage:
#   verify-flatpak-hunspell.sh BUILD_DIR
#
# BUILD_DIR is the directory passed to flatpak-builder's --build-dir
# (the one that ends up containing files/share/hunspell/).
#
# Note: this is a file-presence verifier. We deliberately do NOT run
# enchant-2 inside the sandbox to spot-check that each dict actually
# loads, because `flatpak-builder --run` needs FUSE which doesn't work
# inside the Docker-in-Docker container GitHub Actions uses for the
# Flatpak job. The release-packages workflow's full bundle install
# path covers the functional check end-to-end.

set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 BUILD_DIR [MANIFEST]" >&2
    exit 64
fi

build_dir="$1"

expected=(
    ar bg_BG cs_CZ da_DK de_DE el_GR en_GB en_US es_ES fr_FR
    hu_HU it_IT nb_NO nl_NL pl_PL pt_BR pt_PT ro_RO ru_RU sv_SE
)
expected_count=${#expected[@]}

hunspell_dir="${build_dir}/files/share/hunspell"
actual_count=$(find "$hunspell_dir" -maxdepth 1 -name '*.dic' -type f 2>/dev/null | wc -l)
if [ "$actual_count" -ne "$expected_count" ]; then
    echo "::error::Expected $expected_count hunspell dicts in /app/share/hunspell, found $actual_count"
    ls "$hunspell_dir/" 2>&1 || true
    exit 1
fi

for code in "${expected[@]}"; do
    if [ ! -f "$hunspell_dir/${code}.aff" ] || [ ! -f "$hunspell_dir/${code}.dic" ]; then
        echo "::error::Missing .aff or .dic for ${code} in /app/share/hunspell"
        exit 1
    fi
done

echo "All ${expected_count} hunspell dictionaries present in the Flatpak bundle."
