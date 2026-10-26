# Dependencies

omtex itself is Omega (`lib/omtex.om`). Everything below is a host tool. Each entry gives the
version measured on the reference machine (DGX Spark, Ubuntu 24.04 arm64, 2026-10-26), what it does
here, and what replaces it in Omega. None is linked into the generator: the generated program is a
static Omega binary that only writes LaTeX to stdout.

## Build path

| Tool | Version | Role | Omega successor |
|---|---|---|---|
| `omc` (omega-mv `seed/out/omc`) | omega-mv `91b3c932`, sha256 `189ada82…3b54` | compiles the paper + library; compiles every `omlisting` during `check` | is Omega |
| `pdflatex` (pdfTeX) | 3.141592653-2.6-1.40.25, TeX Live 2023/Debian | renders `.tex` to PDF; the only consumer of omtex output | none claimed. A typesetting engine in Omega is not started |
| TeX Live packages | `texlive-latex-base`, `-latex-recommended`, `-fonts-recommended`, `-latex-extra` 2023.20240207-1 | `article`, `amsmath`, `amsthm`, `geometry`, `hyperref`, `listings`, `xcolor`, `graphicx`, `enumitem`, `parskip`, `mwe` (example image) | as above |
| `cm-super` | 0.3.4-17 | Type 1 T1-encoded Computer Modern. Without it pdfTeX uses bitmap fonts and the PDF text differs from the originals | as above |
| `bibtex` | 0.99d (TeX Live 2023) | only for papers that use `bibtex STYLE FILE`; `bibbegin`/`bibitem` need nothing | as above |
| `sh` (dash), `git`, `sha256sum`, `cat`, `cmp`, `mktemp` | Ubuntu 24.04 | `tools/*.sh`, `tests/run.sh`; `git` fetches the pinned omega-mv commit and supplies `SOURCE_DATE_EPOCH` | an Omega build driver once omega-mv grows one |

## Verification only

| Tool | Version | Role |
|---|---|---|
| `pdftotext`, `pdfinfo`, `pdftoppm` (poppler-utils) | 24.02.0 | `tools/compare.sh`: text, page and pixel comparison with an original paper |
| `awk` (`seed/omc/genkw.awk` of the pin) | mawk 1.3.4 | `tests/run.sh` keyword parity between the listings language and the compiler |

These are read-only checkers, like `cmp`. They do not take part in producing a paper.

## Zenodo draft script

| Tool | Version | Role | Omega successor |
|---|---|---|---|
| `curl` | 8.5.0 (OpenSSL 3.0.13) | HTTPS requests to the Zenodo deposit API | an HTTP client on OmegaNet + OmegaTLS |
| `jq` | jq 1.7 (`/usr/bin/jq`; jaq 3.1.1 also works) | reads and builds deposit JSON | a JSON reader in Omega |
| `md5sum` | coreutils 9.4 | compares the upload with Zenodo's checksum | an MD5 word in Omega |
| `atlas-vault` | local | supplies `ZENODO_TOKEN` to the script's environment only | n/a, operator tooling |
