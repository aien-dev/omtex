#!/bin/sh
# build.sh PAPER.om [OUTDIR] -- Omega paper -> generator -> .tex -> (listing check) -> PDF.
# Env: OMC (pinned omc, sha256 checked), OMTEX_NO_PDF=1 to stop after the .tex,
#      OMTEX_NICE (default "nice -n 19 ionice -c3") prefixed to every heavy step,
#      SOURCE_DATE_EPOCH (default: last commit time of the paper, else 0) for a reproducible PDF.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/tools/pin.sh"
paper=$1
out=${2:-build/$(basename "$(dirname "$paper")")}
nice=${OMTEX_NICE-nice -n 19 ionice -c3}
omtex_check_omc
mkdir -p "$out/listings"
name=$(basename "$paper" .om)
cat "$here/lib/omtex.om" "$paper" > "$out/$name.unit.om"
if ! $nice "$OMC" < "$out/$name.unit.om" > "$out/$name.gen" 2> "$out/$name.omc.err"; then
  echo "build: omc refused $paper:" >&2; cat "$out/$name.omc.err" >&2; exit 1
fi
chmod +x "$out/$name.gen"
"$out/$name.gen" > "$out/$name.tex"
"$out/$name.gen" check "$OMC" "$out/listings" > "$out/$name.listings.txt"
cat "$out/$name.listings.txt"
echo "tex sha256 $(sha256sum < "$out/$name.tex" | cut -d' ' -f1) $out/$name.tex"
[ "${OMTEX_NO_PDF:-0}" = 1 ] && exit 0
src=$(cd "$(dirname "$paper")" && pwd)
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
  SOURCE_DATE_EPOCH=$(git -C "$src" log -1 --format=%ct -- "$(basename "$paper")" 2>/dev/null || true)
fi
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-0}
FORCE_SOURCE_DATE=1
export SOURCE_DATE_EPOCH FORCE_SOURCE_DATE
cd "$out"
run() { TEXINPUTS="$src:" $nice pdflatex -interaction=nonstopmode -halt-on-error -no-shell-escape "$name.tex" > "$name.pdflatex.log" 2>&1 || { tail -30 "$name.pdflatex.log" >&2; exit 1; }; }
run
if grep -q '\\bibdata' "$name.aux"; then BIBINPUTS="$src:" $nice bibtex "$name" > "$name.bibtex.log" 2>&1 || { cat "$name.bibtex.log" >&2; exit 1; }; run; fi
run
unres='Rerun to get\|Reference .* undefined\|Citation .* undefined\|There were undefined references'
if grep -q "$unres" "$name.pdflatex.log"; then echo "build: unresolved references in $name" >&2; grep "$unres" "$name.pdflatex.log" >&2; exit 1; fi
echo "pdf $out/$name.pdf $(pdfinfo "$name.pdf" 2>/dev/null | awk '/^Pages/{print $2}') pages"
