# omtex: write papers in Omega, publish LaTeX and PDF

omtex is an Omega library (`lib/omtex.om`). A paper is an Omega program that calls omtex words such as
`title`, `section`, `para`, `equation`, `figure`, `table`, `bibitem` and `omlisting`. Compiled with the
pinned seeded compiler, the program writes the paper's LaTeX to stdout. `pdflatex` then makes the PDF.

- **Escaped or refused, never passed through.** Prose uses a small markup (`*emph*`, `**bold**`,
  `` `code` ``, `$math$`, `[@cite]`, `[#ref]`, `"quotes"`, `~` tie). Everything else is escaped. A byte
  the library cannot render safely stops the program with `omtex: refused element N: <reason> at byte B`
  and exit 111. Math passes only a check: balanced braces, no `% $ #`, and no `\input`, `\write`, `\def`
  or other deny-listed control sequences.
- **Omega listings are compiled.** `omlisting` bodies must compile with the pinned `omc` (rc 0).
  `omrefuse N` + `omlisting` must be refused with error N. `omfragment` is shown and reported as
  NOT_CHECKED. A failed check stops the build (exit 113). Highlighting uses an `Omega` `listings`
  language generated from the compiler's own keyword table.
- **Deterministic.** The same source gives the same `.tex`, and with `SOURCE_DATE_EPOCH` the same PDF bytes.

Design and rationale: [`docs/DESIGN.md`](docs/DESIGN.md). omtex is a library, not a `target latex` in omc.

## Quick start

Needs Linux AArch64 (the pinned omc emits arm64 ELF), `git`, `sh`, and TeX Live with `cm-super`
(see [`DEPENDENCIES.md`](DEPENDENCIES.md)).

```sh
git clone https://github.com/aien-dev/omtex.git && cd omtex
tools/build.sh examples/hello/hello.om build/hello     # fetches the pinned omc on first use
tests/run.sh                                           # TESTS pass=59 fail=0 not_run=0
```

`tools/build.sh` checks the omc sha256 against `tools/pin.sh` and refuses any other compiler. Set `OMC`
to use an existing copy of the pinned `seed/out/omc`. The build:

1. concatenates `lib/omtex.om` with the paper (Omega has no imports yet) and compiles it;
2. runs the program to produce `paper.tex`;
3. runs `paper.gen check OMC DIR` to compile every Omega listing;
4. runs `pdflatex` (and `bibtex` if the paper uses it) until references settle. An unresolved
   reference fails the build.

## A paper

```
text o1 "11pt"
text c1 "article"
text fe "fontenc"
text fo "T1"
text t1 "Hello from *Omega*"
text a1 "M. Drake Stapleton"
text s1 "Intro"
text l1 "sec:intro"
text p1 "Costs 5% & more_stuff, see Section[#sec:intro]; \"quoted\" and `a_b{c}` and $x^2 + y_{i}$ and **bold *nested* bold**."
fn main to int
docclass o1 c1
usepkgo fo fe
title t1
author a1
begindoc
maketitle
sectionl s1 l1
para p1
enddoc
ret 0
end
```

This is `examples/hello/hello.om`. Each word takes the names of Omega `text` constants as arguments.

| Phase | Words |
|---|---|
| preamble | `docclass opts cls`, `usepkg name`, `usepkgo opts name`, `preamble line`, `omlang`, `title`, `author`, `date` |
| document | `begindoc`, `maketitle`, `docabstract`, `enddoc` |
| structure | `section`, `sectionl t label`, `sectionn` (unnumbered), `subsection`, `subsectn` |
| text | `para`, `paran` (no indent), `prose` (does not end the paragraph), `parbreak`, `rawtex` (math-checked) |
| lists | `itemize`, `itemizeo opts`, `enumerate`, `item`, `endlist` |
| math | `equation`, `equationl label m`, `displaymath`, `align` |
| floats | `figure path caption label`, `table caption label spec`, `cell`, `row`, `hline`, `endtable` |
| references | `bibbegin`, `bibitem key text`, `bibtex style file` |
| listings | `codelang name`, `listing`, `omlisting`, `omrefuse rc`, `omfragment` (each `caption label body`) |

Examples:
- `examples/omega-language`: reproduces the published *Omega* paper (Zenodo 23547811).
- `examples/turing-brief`: reproduces *The Turing* brief from aienos.com.
- `examples/listings`: feature tour, with listings checked by the compiler, a table, a figure, a
  bibliography and math.

## Reproductions

Both papers were reproduced from Omega source. In each case the PDF text matches the published PDF
with 0 differing lines, and every page is pixel-identical to the original `.tex` built with the same
pdfTeX. Details, including the remaining source-level differences, are in
[`evidence/REPRODUCTION.md`](evidence/REPRODUCTION.md). Run the comparison with `tools/compare.sh`.

## Zenodo

`tools/zenodo-draft.sh` creates an unpublished draft (`new`) or a new-version draft of a published
record (`newversion`), uploads the PDF, and checks the md5. `show` and `discard` also exist. It
**never publishes**: any URL containing `publish` is refused, and the run fails unless the deposition is
still an unsubmitted draft afterwards. Publishing is done by a person in the Zenodo web UI.

```sh
atlas-vault run ZENODO_TOKEN -- sh tools/zenodo-draft.sh new build/listings/paper.pdf examples/listings/zenodo.json
atlas-vault run ZENODO_TOKEN -- sh tools/zenodo-draft.sh newversion 23547811 build/omega-language/paper.pdf
```

`--sandbox` uses sandbox.zenodo.org with `ZENODO_SANDBOX_TOKEN`. Runs against zenodo.org are in
`evidence/zenodo-*.txt`.

## License

Apache License 2.0 with LLVM Exceptions; see `LICENSE` and `NOTICE`.
