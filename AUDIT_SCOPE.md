# Audit scope

Written for an outside, independent security audit. Revision described:
`4c86614a1ee09a5b8ca4da6c2f4a7bc958d1fd64` on `main`, 2026-10-26. Everything below is taken from the repository's own files at
that revision; items marked NOT_RUN were not executed while writing this document.

## What this repository is

An Omega library, `lib/omtex.om` (1,176 lines, an `om2` unit), that writes LaTeX. A paper
(`examples/*/paper.om`) is concatenated after the library and compiled with the pinned `omc`; the
resulting generator prints the `.tex` file, and `paper.gen check OMC DIR` compiles every Omega
listing to confirm it is accepted or refused as stated. `docs/DESIGN.md` (110 lines) is the
contract for escaping, the math check, listings and refusal codes. `tools/` holds `build.sh`,
`pin.sh`, `compare.sh` and `zenodo-draft.sh`; `tests/run.sh` is the suite. Licence: Apache 2.0
(`LICENSE`, `NOTICE`).

## What to review, in priority order

1. Prose escaping in `lib/omtex.om` against the table in `docs/DESIGN.md` ("Prose markup"):
   always-escaped characters, paired quotes and emphasis, cite and ref keys, the allowed
   backslash escapes, and refusal of control bytes and malformed UTF-8 (trap 11, exit 111).
2. The math check: printable ASCII only, balanced braces, no `% $ #`, and a deny list of control
   sequences (`\input \include \write \def \edef \gdef \xdef \let \catcode \immediate \openout
   \openin \csname \special \read`). It is a deny list; check whether other primitives or macros
   (for example `\newcommand`, `\renewcommand`, `\expandafter`) can reach the same effects.
   `rawtex` and `preamble` lines use the same check with `&` and `\\` allowed.
3. Listings: bodies containing `\end{lstlisting}`, non-ASCII or control bytes other than LF and
   tab are refused.
4. The `check` path (`txcheck`, `txrun`, `txchild`, `txpath`): it writes `DIR/<label>.om` and runs
   `OMC` with fork and exec. The label character set (`zrkey`) allows `.` and `/`; check whether a
   label such as `../x` leaves `DIR`.
5. `tools/zenodo-draft.sh`: every request goes through `api()`, which refuses any URL containing
   `publish`; the token is written to a header file under `umask 077` and unset; the script ends by
   re-reading the deposition and failing unless it is still unsubmitted. The `eval` of the token
   variable name takes a fixed name chosen by `--sandbox`.
6. `tools/build.sh`: runs `pdflatex -interaction=nonstopmode -halt-on-error -no-shell-escape`,
   and `bibtex` only when the `.aux` names bibliography data.
7. `tools/pin.sh`: fetches omega-mv commit `91b3c9326919faf1491e29ae9276929e8349b8c7` with
   `git fetch --depth 1` and refuses any `omc` whose sha256 differs from
   `189ada82e00bb440cb41351bd252cc68c54a1b1050051cc42a1df700081c3b54`.

## Trust boundaries

- The paper source is written by its author and compiled as code. omtex treats prose and math
  text inside it as data that must not become arbitrary LaTeX.
- pdfTeX is trusted to honour `-no-shell-escape`.
- Zenodo is reached over HTTPS with a bearer token from the environment (`ZENODO_TOKEN` or
  `ZENODO_SANDBOX_TOKEN`).

## Threat model summary

- Assets: the integrity of generated papers, the Zenodo token, published Zenodo records.
- Attackers considered: prose or math text that tries to inject LaTeX; a mistaken run of the
  Zenodo script against a published record.
- Defended: escaping with no raw prose path, math deny list, listing checks, output cap of 4 MiB,
  deterministic output, the publish refusal in `api()`.
- Not defended / explicitly out of scope: a hostile paper author (the paper is a program; it can
  call Omega host words directly); TeX Live vulnerabilities.

## Build from source at a pin

Host tools and versions are listed in `DEPENDENCIES.md` (pdfTeX 3.141592653-2.6-1.40.25, TeX Live
2023, `cm-super` 0.3.4-17, `git`, `sha256sum`). The compiler is fetched by `tools/pin.sh`.

```sh
tools/build.sh examples/listings/paper.om build/listings
OMTEX_NO_PDF=1 tools/build.sh examples/hello/hello.om build/hello   # stop after the .tex
```

## Run every test

NOT_RUN while writing this document. From AGENTS.md:

```sh
tests/run.sh
tools/compare.sh ORIG.tex ORIG.pdf build/X/paper.tex build/X/paper.pdf
```

`tests/run.sh` pairs every refusal case with an accepted case, prints NOT_RUN (never PASS) for
cases the host cannot run, and exits 1 on any FAIL. `tools/compare.sh` needs poppler-utils and an
original paper's `.tex` and PDF. `tools/zenodo-draft.sh` needs a Zenodo token and network; NOT_RUN.

## Known limitations and NOT_RUN

- Hosted CI (`.github/workflows/ci.yml`, added with this document) runs `sh tests/run.sh` with the
  pinned `omc` on a GitHub-hosted arm64 runner and writes an SPDX SBOM. It does not run
  `tools/compare.sh` or `tools/zenodo-draft.sh`.
- Moving the pin requires rerunning `tests/run.sh`, both reproductions and the keyword parity test
  (AGENTS.md).
- A typesetting engine in Omega is not started; pdfTeX stays a host tool (`DEPENDENCIES.md`).
- `curl`, `jq` and `md5sum` are used by the Zenodo script; Omega replacements are named in
  `DEPENDENCIES.md` but not built.

## Dependencies and provenance

- Build path: pinned `omc` (fetched and hash-checked), pdfTeX and TeX Live packages, `bibtex` when
  used, POSIX shell tools. The generator is a static Omega binary that only writes LaTeX to stdout
  (`DEPENDENCIES.md`).
- Verification only: poppler-utils 24.02.0, mawk 1.3.4 (for the pin's `seed/omc/genkw.awk`).
- Zenodo script: curl 8.5.0, jq 1.7, md5sum (coreutils 9.4).

## Evidence

- `evidence/tests.txt`: `TESTS pass=59 fail=0 not_run=0`.
- `evidence/REPRODUCTION.md` with `compare-omega-language.txt` and `compare-turing-brief.txt`:
  reproductions of two published papers (for the first, 0 differing text lines and 9 of 9 pages
  pixel-identical against the original rebuilt on the same TeX Live).
- `evidence/zenodo-new.txt` and `evidence/zenodo-newversion.txt`: draft runs against zenodo.org.

AGENTS.md: never edit a recorded result. These are the author's logs, not independent
reproduction.
