#!/bin/sh
# compare.sh ORIG.tex ORIG.pdf OMTEX.tex OMTEX.pdf -- compare an omtex reproduction with the original.
#  1. text: pdftotext -layout of the published ORIG.pdf vs OMTEX.pdf (diff line count, 0 = identical)
#  2. pages: page counts
#  3. pixels: ORIG.tex compiled here with the same pdflatex, rendered at 100 dpi, page-by-page cmp
#     with OMTEX.pdf (isolates omtex from TeX Live version differences)
#  4. source: word-level diff of ORIG.tex vs OMTEX.tex (whitespace-insensitive), as counted pairs
set -eu
otex=$(realpath "$1") opdf=$(realpath "$2") mtex=$(realpath "$3") mpdf=$(realpath "$4")
nice=${OMTEX_NICE-nice -n 19 ionice -c3}
W=$(mktemp -d "${TMPDIR:-/tmp}/omtex-cmp.XXXXXX")
trap 'rm -rf "$W"' EXIT
pages() { pdfinfo "$1" | awk '/^Pages/{print $2}'; }
echo "orig.tex sha256 $(sha256sum < "$otex" | cut -d' ' -f1)"
echo "orig.pdf sha256 $(sha256sum < "$opdf" | cut -d' ' -f1) producer $(pdfinfo "$opdf" | sed -n 's/^Producer: *//p')"
echo "omtex.tex sha256 $(sha256sum < "$mtex" | cut -d' ' -f1)"
echo "omtex.pdf producer $(pdfinfo "$mpdf" | sed -n 's/^Producer: *//p')"
pdftotext -layout "$opdf" "$W/o.txt"; pdftotext -layout "$mpdf" "$W/m.txt"
echo "text: published PDF vs omtex PDF differing lines: $(diff "$W/o.txt" "$W/m.txt" | grep -c '^[<>]' || true)"
echo "pages: published $(pages "$opdf") omtex $(pages "$mpdf")"
cp "$otex" "$W/orig.tex"
( cd "$W" && for i in 1 2; do $nice pdflatex -interaction=nonstopmode -halt-on-error -no-shell-escape orig.tex > /dev/null; done )
pdftoppm -r 100 "$W/orig.pdf" "$W/l"; pdftoppm -r 100 "$mpdf" "$W/m"
same=0 total=0
for f in "$W"/l-*.ppm; do
  total=$((total + 1)); g=$W/m-${f##*/l-}
  if [ -f "$g" ] && cmp -s "$f" "$g"; then same=$((same + 1)); else echo "pixels: page ${f##*/l-} differs"; fi
done
echo "pixels: original .tex built here vs omtex PDF, 100 dpi: $same/$total pages identical"
tr -s ' \n\t' '\n\n\n' < "$otex" > "$W/o.w"; tr -s ' \n\t' '\n\n\n' < "$mtex" > "$W/m.w"
echo "source word diff (count, side, token):"
diff "$W/o.w" "$W/m.w" | grep '^[<>]' | sort | uniq -c | sort -rn || echo "  none"
