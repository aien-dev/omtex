# omtex design

Status: IMPLEMENTED and EXERCISED on a Linux AArch64 host (see `evidence/`). Not a compiler target.

## Goal

Author a paper as an Omega program and get LaTeX (and, through pdflatex, a PDF) whose every byte
was emitted by checked Omega code. Escaping and math are where hand-written LaTeX goes wrong, so
the library refuses input it cannot render safely instead of passing it through.

## Shape: a library, not a compiler target

A paper is an Omega unit. `lib/omtex.om` (an OM-2 unit) is concatenated in front of the paper
body, because Omega has no imports yet (FR-3: units concatenate). The pinned seeded compiler
builds that unit into a generator; running the generator writes the `.tex` file on stdout.

```
cat lib/omtex.om paper.om | omc > paper.gen      # Omega -> AArch64 program
./paper.gen > paper.tex                          # program -> LaTeX
pdflatex paper.tex                               # host renderer (recorded dependency)
```

The library depends on one OM-2 feature: unsized views (`t view uchar *`, OMEGESE 9.13). A
`text` literal of any length can be passed to a library word, so the document reads as a list of
calls such as `section s1` and `para p1`. The output buffer is a global the library names
directly (globals are never passed, error 19).

Why not `target latex` in omc: LaTeX is a document format, not an instruction set. Putting it in
the compiler would add a second lowering with no use for types, registers or traps, enlarge the
compiler's trusted surface, and couple paper releases to the compiler's serial merge queue. A
library keeps the compiler unchanged and the escaping rules in ordinary, testable Omega. What a
compiler change would buy is imports (FR-3), so a paper could name the library instead of being
concatenated with it; that is already an open request, not something to add for this.

## Prose markup (the only way text reaches LaTeX)

Every prose word (`title`, `author`, `date`, `abstract`, `para`, `section`, `item`, `cell`,
captions, bibliography entries) scans its bytes once:

| Source | LaTeX | Rule |
|---|---|---|
| `# $ % & _ { }` | `\#` ... `\}` | always escaped |
| `^ < > \|` | `\textasciicircum{}` ... | always escaped |
| `~` | `~` | a tie (non-breaking space), as in LaTeX: `Lemma~2` |
| `[` `]` | `{[}` `{]}` | so an `\item` never takes a prose `[` as its option |
| `"` ... `"` | ` `` ` ... `''` | must pair inside the element |
| `*x*` / `**x**` | `\emph{x}` / `\textbf{x}` | must nest and close inside the element |
| `` `x` `` | `\texttt{x}` | contents escaped as code |
| `$m$` | `$m$` | `m` passes the math check |
| `[@k]` / `[#k]` | `~\cite{k}` / `~\ref{k}` | key characters `A-Za-z0-9:._-+/,` |
| `\c` (the Omega text `\\c`) | literal `c` | only for `` \ * ` $ [ ] " ~ ``; any other backslash is refused |
| tab, LF | space | |
| other control bytes, malformed UTF-8 | refused | |

A refusal writes `omtex: refused element N: <reason> at byte B` to stderr and traps 11
(exit 111). There is no silent fallback and no raw prose path.

Inline math ends at the first `$` that is not part of a backslash pair, so `$\$5$` is one span.

## Paragraphs and displays

`para t` writes `t` and ends the paragraph; `paran t` does the same with `\noindent`. `prose t`
writes `t` without ending the paragraph, so it can lead into a display. `equation`, `displaymath`
and `align` do not end the paragraph either: text after `\end{equation}` continues it, exactly as
in hand-written LaTeX. `parbreak` ends a paragraph explicitly. This matters for indentation: the
Turing brief reproduction showed that ending the paragraph after a display indents the next line.

## Math check

Math (`$m$`, `equation`, `displaymath`, `align`) is passed through only when: every byte is
printable ASCII; `{` `}` balance (escaped `\{ \}` excluded); `% $ #` do not appear; `&` and `\\`
appear only in `align`; and no control sequence from the deny list (`\input \include \write \def
\edef \gdef \xdef \let \catcode \immediate \openout \openin \csname \special \read`) is used.
`rawtex` and `preamble` lines use the same check with `&` and `\\` allowed.

## Listings

`listing` (any language), `omlisting` (Omega, must compile with rc 0), `omrefused` (Omega, must
be refused with a stated rc) and `omfragment` (Omega, shown, explicitly not compiled). Bodies are
verbatim inside `lstlisting`; a body containing `\end{lstlisting}`, a non-ASCII byte or a control
byte other than LF/tab is refused. `omlang` emits `\lstdefinelanguage{Omega}` whose keyword
groups are the pin's keyword table (`seed/omc/genkw.awk`) plus the OM-2 words; `tests/run.sh`
compares them. Keyword groups are coloured (blue, teal, violet, orange) and comments are grey
italic, because the `cmtt` typewriter font has no bold, so bold keywords would not show.

Running the generator as `paper.gen check OMC DIR` writes each Omega listing to `DIR/<label>.om`,
runs `OMC` on it (fork, `dupfd`, `execprog`, `waitpid`, all Omega host words) and prints
`LISTING <label> want=W got=G PASS|FAIL`, then `LISTINGS pass=P fail=F fragments=R`. Any FAIL
exits 113.

## Order and structure checks

Preamble words after `begindoc`, body words before it, unclosed lists/tables/emphasis/quotes at
`enddoc`, a second `enddoc`, and output over 4 MiB are refused. Output depends only on the
source: no clock, environment or randomness is read, so the same source gives identical bytes.
`tools/build.sh` exports `SOURCE_DATE_EPOCH` (default: the paper's last git commit time, else 0)
and `FORCE_SOURCE_DATE=1`, so pdfTeX's dates and IDs are fixed too and the PDF is byte-identical
across builds (`tests/run.sh` checks both).

## Zenodo

`tools/zenodo-draft.sh` creates a new draft or a new-version draft and uploads the PDF. It checks
the upload md5 against Zenodo's checksum, then re-reads the deposition and fails unless it is still
unsubmitted. Every request goes through one function that refuses any URL containing `publish`.
Publishing stays a human action in the Zenodo web UI.

## Host dependencies

pdflatex (TeX Live) renders and is the only consumer of the output; `sh`, `curl`, `jq`, `sha256sum`,
`cmp`, `pdftotext` run the build, tests and the Zenodo draft script. See `DEPENDENCIES.md`.
