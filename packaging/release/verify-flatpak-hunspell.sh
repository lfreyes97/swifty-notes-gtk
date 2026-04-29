#!/usr/bin/env bash
# Smoke-test the bundled hunspell dictionaries inside a freshly built
# Flatpak. Catches regressions when bumping the LibreOffice/dictionaries
# pin or editing the install list in the manifest — without this, a
# silently dropped dict or an upstream rename would only surface when
# end users complain that their language is missing.
#
# Usage:
#   verify-flatpak-hunspell.sh BUILD_DIR MANIFEST
#
# BUILD_DIR is the directory passed to flatpak-builder's --build-dir
# (the one that ends up containing files/share/hunspell/).
# MANIFEST is the rendered .yml manifest path; needed so we can run
# `flatpak-builder --run` to spot-check enchant inside the sandbox.

set -euxo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 BUILD_DIR MANIFEST" >&2
    exit 64
fi

build_dir="$1"
manifest="$2"

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

# Spot-check that enchant-2 inside the bundle actually loads each dict
# and flags an obvious not-a-word as misspelt. Covers four script
# families (Latin, Latin-extended, Cyrillic, Greek, Arabic) so a broken
# dict for any of them surfaces here rather than at user runtime.
manifest_dir="$(dirname "$manifest")"
manifest_basename="$(basename "$manifest")"
build_basename="$(basename "$build_dir")"

for code in en_US de_DE ru_RU el_GR ar; do
    result=$(cd "$manifest_dir" && flatpak-builder --run "$build_basename" "$manifest_basename" \
        sh -c "printf '%s\n' xyzqwertynotaword | enchant-2 -d ${code} -l" 2>&1 \
        | tr -d '\r' | tail -1)
    if [ "$result" != "xyzqwertynotaword" ]; then
        echo "::error::enchant-2 -d ${code} did not flag the typo (got: '$result')"
        exit 1
    fi
done

echo "All ${expected_count} hunspell dictionaries present and loadable."
