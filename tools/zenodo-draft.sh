#!/bin/sh
# zenodo-draft.sh -- put a built paper PDF into an UNPUBLISHED Zenodo draft. It never publishes:
# every request goes through api(), which refuses any path containing "publish", and the script
# finishes by re-reading the deposition and failing unless it is still an unsubmitted draft.
# Publishing stays a human action in the Zenodo web UI.
#
#   zenodo-draft.sh [--sandbox] new PDF METADATA.json
#       new standalone draft; METADATA.json is the Zenodo deposit "metadata" object
#   zenodo-draft.sh [--sandbox] newversion RECORD_ID PDF [METADATA.json]
#       new-version draft of a published record: inherited files are removed, PDF uploaded,
#       publication_date set to today (UTC), optional METADATA.json fields merged over the old ones
#   zenodo-draft.sh [--sandbox] show DEPOSITION_ID
#       print state, URL and files; exits 6 unless it is an unpublished draft
#   zenodo-draft.sh [--sandbox] discard DEPOSITION_ID
#       delete an unpublished draft (Zenodo refuses this for published records)
#
# Token: $ZENODO_TOKEN (sandbox: $ZENODO_SANDBOX_TOKEN), e.g.
#   atlas-vault run ZENODO_TOKEN -- sh tools/zenodo-draft.sh ...
# The token is passed to curl in a mode-600 header file, never in argv, and never printed.
set -eu
host=https://zenodo.org tokvar=ZENODO_TOKEN
if [ "${1:-}" = --sandbox ]; then host=https://sandbox.zenodo.org tokvar=ZENODO_SANDBOX_TOKEN; shift; fi
eval "tok=\${$tokvar:-}"
# Zenodo tokens are alphanumeric; a stored value may carry quotes or a newline from how it was saved.
tok=$(printf %s "$tok" | tr -d "'\"[:space:]")
[ -n "$tok" ] || { echo "zenodo-draft: \$$tokvar is not set" >&2; exit 2; }
W=$(mktemp -d "${TMPDIR:-/tmp}/zenodo-draft.XXXXXX")
trap 'rm -rf "$W"' EXIT
umask 077
printf 'Authorization: Bearer %s\n' "$tok" > "$W/h"
unset tok

# api METHOD URL-or-PATH [curl args...] -> body on stdout; fails on HTTP >= 400.
api() {
  m=$1 u=$2; shift 2
  case $u in http*) ;; *) u=$host/api$u ;; esac
  case $u in *publish*) echo "zenodo-draft: refusing $u (this tool never publishes)" >&2; exit 3 ;; esac
  code=$(curl -sS -o "$W/body" -w '%{http_code}' -X "$m" -H @"$W/h" "$@" "$u")
  if [ "$code" -ge 400 ]; then echo "zenodo-draft: $m $u -> HTTP $code: $(cut -c1-400 "$W/body")" >&2; exit 4; fi
  cat "$W/body"
}
upload() { # upload BUCKET-URL PDF
  name=$(basename "$2")
  api PUT "$1/$name" -H 'Content-Type: application/octet-stream' --data-binary @"$2" > "$W/up"
  want=$(md5sum < "$2" | cut -d' ' -f1)
  got=$(jq -r '.checksum' < "$W/up")
  [ "$got" = "md5:$want" ] || { echo "zenodo-draft: upload checksum $got, local md5:$want" >&2; exit 5; }
  echo "file $name md5:$want size $(wc -c < "$2")"
}
verify() { # verify ID: must still be an unsubmitted draft
  api GET "/deposit/depositions/$1" > "$W/d"
  st=$(jq -r '.state' < "$W/d"); sub=$(jq -r '.submitted' < "$W/d")
  echo "draft $1 state=$st submitted=$sub"
  echo "title $(jq -r '.metadata.title' < "$W/d") | publication_date $(jq -r '.metadata.publication_date // "-"' < "$W/d")"
  echo "url $(jq -r '.links.html' < "$W/d")"
  jq -r '.files[] | "zenodo-file \(.filename) md5:\(.checksum)"' < "$W/d"
  [ "$sub" = false ] && [ "$st" != done ] || { echo "zenodo-draft: deposition $1 is not an unpublished draft" >&2; exit 6; }
}
need_pdf() { [ -f "$1" ] && [ "$(head -c 5 "$1")" = %PDF- ] || { echo "zenodo-draft: $1 is not a PDF" >&2; exit 2; }; }

cmd=${1:-}; [ $# -gt 0 ] && shift
case $cmd in
new)
  [ $# = 2 ] || { echo "usage: zenodo-draft.sh [--sandbox] new PDF METADATA.json" >&2; exit 2; }
  need_pdf "$1"; jq -e 'type == "object" and has("title")' < "$2" > /dev/null
  api POST /deposit/depositions -H 'Content-Type: application/json' -d '{}' > "$W/n"
  id=$(jq -r '.id' < "$W/n"); bucket=$(jq -r '.links.bucket' < "$W/n")
  upload "$bucket" "$1"
  jq '{metadata: .}' < "$2" > "$W/m"
  api PUT "/deposit/depositions/$id" -H 'Content-Type: application/json' --data-binary @"$W/m" > /dev/null
  verify "$id" ;;
newversion)
  [ $# -ge 2 ] || { echo "usage: zenodo-draft.sh [--sandbox] newversion RECORD_ID PDF [METADATA.json]" >&2; exit 2; }
  need_pdf "$2"
  api POST "/deposit/depositions/$1/actions/newversion" > "$W/v"
  draft=$(jq -r '.links.latest_draft' < "$W/v")
  api GET "$draft" > "$W/n"
  id=$(jq -r '.id' < "$W/n"); bucket=$(jq -r '.links.bucket' < "$W/n")
  jq -r '.files[].id' < "$W/n" | while read -r f; do api DELETE "/deposit/depositions/$id/files/$f" > /dev/null; done
  upload "$bucket" "$2"
  today=$(date -u +%Y-%m-%d)
  if [ $# -ge 3 ]; then jq --arg d "$today" --slurpfile x "$3" '{metadata: (.metadata + $x[0] + {publication_date: $d})}' < "$W/n" > "$W/m"
  else jq --arg d "$today" '{metadata: (.metadata + {publication_date: $d})}' < "$W/n" > "$W/m"; fi
  jq 'del(.metadata.doi)' < "$W/m" > "$W/m2"
  api PUT "/deposit/depositions/$id" -H 'Content-Type: application/json' --data-binary @"$W/m2" > /dev/null
  verify "$id" ;;
discard)
  [ $# = 1 ] || { echo "usage: zenodo-draft.sh [--sandbox] discard DEPOSITION_ID" >&2; exit 2; }
  api GET "/deposit/depositions/$1" > "$W/d"
  [ "$(jq -r '.submitted' < "$W/d")" = false ] || { echo "zenodo-draft: $1 is published; not touching it" >&2; exit 6; }
  api DELETE "/deposit/depositions/$1" > /dev/null
  echo "discarded draft $1" ;;
show)
  [ $# = 1 ] || { echo "usage: zenodo-draft.sh [--sandbox] show DEPOSITION_ID" >&2; exit 2; }
  verify "$1" ;;
*) sed -n '2,20p' "$0" >&2; exit 2 ;;
esac
