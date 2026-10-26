#!/bin/sh
# tests/run.sh -- omtex test suite. Every refusal case is paired with a minimally different accepted
# case, so a refusal cannot pass by the library refusing everything. Prints one line per case and a
# summary; exits 1 on any FAIL. Cases that cannot run on this host print NOT_RUN (never PASS).
# Env: OMC (pinned omc; fetched by tools/pin.sh when absent), OMTEX_NICE as in tools/build.sh.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/tools/pin.sh"
nice=${OMTEX_NICE-nice -n 19 ionice -c3}
( omtex_check_omc ) || { echo "FAIL pin: omc missing or not the pinned build"; exit 1; }
T=$(mktemp -d "${TMPDIR:-/tmp}/omtex-test.XXXXXX")
trap '[ -n "${OMTEX_KEEP:-}" ] || rm -rf "$T"' EXIT
pass=0 fail=0 notrun=0
ok()  { pass=$((pass + 1)); echo "PASS $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1: $2"; }
nr()  { notrun=$((notrun + 1)); echo "NOT_RUN $1: $2"; }

# doc NAME: stdin holds "text" lines, a line "---", then body words; wrapped in a minimal document.
doc() {
  { echo 'text zzcls "article"'; echo 'text zzopt "11pt"'
    sed '/^---$/,$d'
    echo 'fn main to int'; echo 'docclass zzopt zzcls'; echo 'begindoc'
    sed -n '/^---$/,$p' "$T/$1.in" | sed 1d
    echo 'enddoc'; echo 'ret 0'; echo 'end'; } < "$T/$1.in" > "$T/$1.om"
}
# gen NAME [ARGS]: compile lib+case, run the generator; sets rc, output in $T/NAME.out / .err.
gen() {
  n=$1; shift
  if ! cat "$here/lib/omtex.om" "$T/$n.om" | $nice "$OMC" > "$T/$n.gen" 2> "$T/$n.cerr"; then
    rc=compile; return
  fi
  chmod +x "$T/$n.gen"
  "$T/$n.gen" "$@" > "$T/$n.out" 2> "$T/$n.err"; rc=$?
}
# expect NAME RC [FIXED-STRING...]: case built by doc(); generator exit must be RC and stdout must
# contain each string.
expect() {
  n=$1 want=$2; shift 2
  doc "$n"; gen "$n"
  if [ "$rc" != "$want" ]; then bad "$n" "rc=$rc want=$want $(cat "$T/$n.err" "$T/$n.cerr" 2>/dev/null | head -2)"; return; fi
  for s in "$@"; do
    grep -qF -- "$s" "$T/$n.out" || { bad "$n" "output lacks: $s"; return; }
  done
  if [ "$want" = 111 ]; then
    grep -q '^omtex: refused element [0-9]*: ' "$T/$n.err" || { bad "$n" "no refusal message"; return; }
  fi
  ok "$n"
}
case_() { cat > "$T/$1.in"; }

# ---- escaping (prose) --------------------------------------------------------------------------
case_ esc <<'EOF'
text p "50% & a_b #1 {x} ^ < > | tie~here, tilde \\~ and backslash \\\\ done"
---
para p
EOF
expect esc 0 '50\% \& a\_b \#1 \{x\} \textasciicircum{} \textless{} \textgreater{} \textbar{} tie~here, tilde \textasciitilde{} and backslash \textbackslash{} done'

# Leak detector: a TeX special preceded by anything but a backslash. Negative control: the detector
# must fire on the raw prose, otherwise it proves nothing about the escaped output.
leak() { grep -E '(^|[^\\])[%&_#]' "$1" > /dev/null; }
grep '^text p ' "$T/esc.in" > "$T/esc.raw"
if ! leak "$T/esc.raw"; then bad esc-leak-control "detector does not fire on raw % & _ #"
elif sed -n '/begin{document}/,/end{document}/p' "$T/esc.out" > "$T/esc.body" && leak "$T/esc.body"; then
  bad esc-leak "unescaped special in output: $(grep -E '(^|[^\\])[%&_#]' "$T/esc.body" | head -1)"
else ok esc-leak; fi

case_ markup <<'EOF'
text p "*em* **bold** `a_b{c}` $x^2$ \"quoted\" [@k1,k2] [#sec:a] \\* \\$ \\[x\\]"
---
para p
EOF
expect markup 0 '\emph{em} \textbf{bold} \texttt{a\_b\{c\}} $x^2$ ``quoted'"''"' ~\cite{k1,k2} ~\ref{sec:a} * \$ {[}x{]}'

case_ utf8 <<'EOF'
text p "Gödel – π"
---
para p
EOF
expect utf8 0 'Gödel – π'

# ---- refusal pairs: (accepted, refused) ----------------------------------------------------------
pair() { # pair NAME BODY-WORD GOOD-TEXT BAD-TEXT
  printf 'text v "%s"\n---\n%s v\n' "$3" "$2" > "$T/$1-ok.in"
  printf 'text v "%s"\n---\n%s v\n' "$4" "$2" > "$T/$1-refused.in"
  expect "$1-ok" 0; expect "$1-refused" 111
}
pair backslash para 'C:\\\\temp' 'C:\\temp'
pair emph para 'F\\* and *x*' 'F* and x'
pair emph-nest para '**a *b* c**' '**a *b** c*'
pair quote para '\"hi\" she said' '\"hi she said'
pair code para '`x`' '`x'
pair math-pct para '$50\\%$' '$50%$'
pair math-dollar para '$a$ and $b$' '$a$ and $b'
pair math-brace para '$x^{2}$' '$x^{2$'
pair math-input para '$\\mathrm{input}$' '$\\input{/etc/passwd}$'
pair math-csname para '$\\alpha$' '$\\csname foo\\endcsname$'
pair disp-def equation 'e^{i\\pi}' '\\def\\x{1}\\x'
pair disp-write displaymath 'a = b' '\\immediate\\write18{id}'
pair amp-outside para '$a \\le b$' '$a & b$'
pair cite-key para '[@shannon48]' '[@bad key]'
pair ref-key para '[#sec:a]' '[#sec a]'
# labels go through sectionl, which takes two texts
printf 'text s "Intro"\ntext v "sec:intro"\n---\nsectionl s v\n' > "$T/label-ok.in"
printf 'text s "Intro"\ntext v "sec:intro}\\\\input{x}"\n---\nsectionl s v\n' > "$T/label-refused.in"
expect label-ok 0 '\section{Intro}\label{sec:intro}'; expect label-refused 111
printf 'text o "leftmargin=*"\ntext i "a"\n---\nitemizeo o\nitem i\nendlist\n' > "$T/opt-ok.in"
printf 'text o "leftmargin=*]\\\\input{x}"\ntext i "a"\n---\nitemizeo o\nitem i\nendlist\n' > "$T/opt-refused.in"
expect opt-ok 0 '\begin{itemize}[leftmargin=*]'; expect opt-refused 111
printf 'text i "a"\n---\nitemize\nitem i\nendlist\n' > "$T/list-ok.in"
printf 'text i "a"\n---\nitemize\nitem i\n' > "$T/list-refused.in"
expect list-ok 0; expect list-refused 111
printf 'text i "a"\n---\nitemize\nitem i\nendlist\n' > "$T/item-ok.in"
printf 'text i "a"\n---\nitem i\n' > "$T/item-refused.in"
expect item-ok 0; expect item-refused 111
printf 'text sh "sh"\ntext c "c"\ntext l "lst:x"\ntext b "echo end{lstlisting}\\n"\n---\ncodelang sh\nlisting c l b\n' > "$T/lst-ok.in"
printf 'text sh "sh"\ntext c "c"\ntext l "lst:x"\ntext b "echo \\\\end{lstlisting}\\n"\n---\ncodelang sh\nlisting c l b\n' > "$T/lst-refused.in"
expect lst-ok 0; expect lst-refused 111
printf 'text c "c"\ntext l "lst:x"\ntext b "x\\n"\ntext sh "sh"\n---\ncodelang sh\nlisting c l b\n' > "$T/lang-ok.in"
printf 'text c "c"\ntext l "lst:x"\ntext b "x\\n"\n---\nlisting c l b\n' > "$T/lang-refused.in"
expect lang-ok 0; expect lang-refused 111

# phase order: a body word before begindoc, a preamble word after it
cat > "$T/order-ok.om" <<'EOF'
text c "article"
text o "11pt"
text p "amsmath"
text v "x"
fn main to int
docclass o c
usepkg p
begindoc
para v
enddoc
ret 0
end
EOF
sed 's/^usepkg p$/para v/' "$T/order-ok.om" > "$T/order-refused.om"
for n in order-ok order-refused; do
  gen "$n"; want=0; [ "$n" = order-refused ] && want=111
  [ "$rc" = "$want" ] && ok "$n" || bad "$n" "rc=$rc want=$want"
done
cp "$T/order-ok.om" "$T/order-late.om"
sed -i 's/^para v$/usepkg p/' "$T/order-late.om"
gen order-late; [ "$rc" = 111 ] && ok order-late-preamble || bad order-late-preamble "rc=$rc want=111"

# ---- listings check mode ------------------------------------------------------------------------
lcase() { # lcase NAME REFUSE-RC|- CODE   (CODE uses \n, the Omega string escape)
  { printf 'text c "c"\ntext l "lst:t"\ntext b "%s"\n---\n' "$3"
    [ "$2" = - ] || echo "omrefuse $2"
    echo 'omlisting c l b'; } > "$T/$1.in"
  doc "$1"
  # omlang belongs to the preamble
  sed -i 's/^begindoc$/omlang\nbegindoc/' "$T/$1.om"
}
lcheck() { # lcheck NAME WANT-RC WANT-LINE
  mkdir -p "$T/$1.d"; gen "$1" check "$OMC" "$T/$1.d"
  if [ "$rc" != "$2" ]; then bad "$1" "rc=$rc want=$2 $(cat "$T/$1.err" | head -1)"; return; fi
  grep -qF -- "$3" "$T/$1.out" || { bad "$1" "no line: $3"; return; }
  ok "$1"
}
lcase lst-compiles - 'fn main to int\nret 0\nend\n'
lcheck lst-compiles 0 'LISTING lst:t want=0 got=0 PASS'
lcase lst-broken - 'fn main to int\nret 0\nret 1\nend\n'
lcheck lst-broken 113 'LISTING lst:t want=0 got=17 FAIL'
lcase lst-refusal-ok 17 'fn main to int\nret 0\nret 1\nend\n'
lcheck lst-refusal-ok 0 'LISTING lst:t want=17 got=17 PASS'
lcase lst-refusal-wrong 16 'fn main to int\nret 0\nret 1\nend\n'
lcheck lst-refusal-wrong 113 'LISTING lst:t want=16 got=17 FAIL'
lcase lst-refusal-compiles 17 'fn main to int\nret 0\nend\n'
lcheck lst-refusal-compiles 113 'LISTING lst:t want=17 got=0 FAIL'

# ---- determinism --------------------------------------------------------------------------------
gen esc; cp "$T/esc.out" "$T/esc.1"; gen esc
cmp -s "$T/esc.1" "$T/esc.out" && ok determinism-tex || bad determinism-tex "two runs differ"
if command -v pdflatex > /dev/null; then
  ex=$here/examples/listings/paper.om
  ( cd "$here" && SOURCE_DATE_EPOCH=1700000000 tools/build.sh "$ex" "$T/b1" ) > "$T/b1.log" 2>&1 \
  && ( cd "$here" && SOURCE_DATE_EPOCH=1700000000 tools/build.sh "$ex" "$T/b2" ) > "$T/b2.log" 2>&1
  if [ $? -ne 0 ]; then bad determinism-pdf "build failed: $(tail -2 "$T/b1.log" "$T/b2.log")"
  elif cmp -s "$T/b1/paper.tex" "$T/b2/paper.tex" && cmp -s "$T/b1/paper.pdf" "$T/b2/paper.pdf"; then ok determinism-pdf
  else bad determinism-pdf "tex or pdf differ between two builds"; fi
else nr determinism-pdf "pdflatex not installed"; fi

# ---- keyword parity with the pinned compiler ----------------------------------------------------
kw=$(dirname "$OMC")/../omc/genkw.awk
om2='rotr rotl unroll inline fresh abstract seal open holds layout field at little big part out ops export requires ensures invariant result old om2 ir'
if [ -r "$kw" ]; then
  # note is the line-comment word: it is highlighted as a comment (morecomment), not a keyword
  sed -n 's/.*n=split("\([^"]*\)".*/\1/p' "$kw" | tr ' ' '\n' | cut -d: -f1 | grep -E '^[a-z0-9]+$' | grep -vx note > "$T/kw.pin"
  grep -qF 'morecomment=[l]{note}' "$here/lib/omtex.om" || bad keyword-note "note is not the listings comment"
  for w in $om2; do echo "$w"; done >> "$T/kw.pin"
  sort -u -o "$T/kw.pin" "$T/kw.pin"
  grep '^text zlang[2-5] ' "$here/lib/omtex.om" | sed 's/.*{\([^}]*\)}.*/\1/' | tr ',' '\n' | sort -u > "$T/kw.lib"
  if cmp -s "$T/kw.pin" "$T/kw.lib"; then ok keyword-parity
  else bad keyword-parity "$(diff "$T/kw.pin" "$T/kw.lib" | grep '^[<>]' | tr '\n' ' ')"; fi
else nr keyword-parity "no genkw.awk next to $OMC"; fi

# ---- pin refusal --------------------------------------------------------------------------------
cp "$OMC" "$T/omc.other"; printf 'x' >> "$T/omc.other"
if ( OMC=$T/omc.other; omtex_check_omc ) 2> /dev/null; then bad pin-refusal "a modified omc was accepted"
else ok pin-refusal; fi

# ---- zenodo-draft never publishes (offline: the refusal happens before any request) ------------
printf '%%PDF-1.4\n' > "$T/z.pdf"
ZENODO_TOKEN=offline-test sh "$here/tools/zenodo-draft.sh" newversion '1/actions/publish#' "$T/z.pdf" > /dev/null 2> "$T/z.err"
zrc=$?
if [ "$zrc" = 3 ] && grep -q 'never publishes' "$T/z.err"; then ok zenodo-publish-refusal
else bad zenodo-publish-refusal "rc=$zrc $(head -1 "$T/z.err")"; fi

echo "TESTS pass=$pass fail=$fail not_run=$notrun"
[ "$fail" = 0 ]
