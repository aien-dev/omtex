# Reproducing published papers with omtex

Measured 2026-10-26 on the DGX Spark (arm64): omc pinned at omega-mv `91b3c932` (sha256 `189ada82…3b54`),
pdfTeX 3.141592653-2.6-1.40.25 (TeX Live 2023/Debian) with `cm-super`. The published PDFs were made with
pdfTeX 1.40.29. Raw output from `tools/compare.sh` is in `compare-*.txt`.

## 1. Omega: A Programming Language Built for Verified Programs

- Original: Zenodo record 23547811 (concept DOI 10.5281/zenodo.23547810), `paper.pdf` sha256 `8e2674d1…1820`;
  source `aien-dev/aienos.com` `public/research/omega-language/paper.tex` sha256 `88e6aaf8…ebf6`.
- omtex source: `examples/omega-language/paper.om`. The generated `.tex` has sha256 `d29ca10a…0b20`.

| Check | Result |
|---|---|
| Text, published PDF vs omtex PDF (`pdftotext -layout`) | 0 differing lines |
| Pages | 9 and 9 |
| Pixels, original `.tex` built here vs omtex PDF (100 dpi) | 9 of 9 pages identical |
| Sections / subsections / labels / refs / items | 10/7/3/4/10 in both |
| Citations, equations | none in the original, none in the reproduction |

Source-level differences (word diff, whitespace ignored):
- `||` (5 places) is emitted as `\textbar{}\textbar{}`. omtex escapes every `|` in prose. Under T1
  encoding both forms produce the same glyphs, and the pixel comparison shows no change.
- `\label{…}` sits on the same line as its `\section{…}` (3 places). This changes no output.
- Paragraph line breaks inside the source are not preserved, because each paragraph is one Omega text.

The published PDF differs from *the original `.tex` rebuilt here* by small antialiasing/positioning
differences on 6 of 9 pages, identical in extent for the omtex PDF. The cause is TeX Live 2023 versus the
newer TeX Live used for publication, not omtex. Without `cm-super`, both builds fall back to bitmap fonts,
and `pdftotext` then breaks ligatures ("Veried").

## 2. The Turing: A Unit of Verified Explanatory Gain (brief)

- Original: `aien-dev/aienos.com` `public/research/the-turing-brief/paper.pdf` sha256 `7689932e…3146`,
  source `paper.tex` sha256 `4bada1db…e413`.
- omtex source: `examples/turing-brief/paper.om`. The generated `.tex` has sha256 `29f964fe…6a67`.

| Check | Result |
|---|---|
| Text, published PDF vs omtex PDF | 0 differing lines |
| Pages | 3 and 3 |
| Pixels, original `.tex` built here vs omtex PDF | 3 of 3 pages identical |
| Sections / equations / itemize / items / `$` math delimiters | 9/1/2/11/40 in both |

Source-level differences: `\noindent\textit{…}` (3 places) is written as `paran` with `*…*`, which emits
`\noindent \emph{…}`. That is identical upright-context output.

## Library changes forced by the reproductions

- `~` in prose is a tie, as in LaTeX (`Lemma~2`); `\~` gives a literal tilde.
- Displays (`equation`, `displaymath`, `align`) do not end the paragraph, and `prose` writes a lead-in
  that does not end its paragraph either. This matches LaTeX, where text right after `\end{equation}`
  continues the paragraph. `parbreak` ends a paragraph explicitly.
- The fail-closed scanner refused a literal `F*` in the Omega paper (an unclosed emphasis); the source
  now says `F\\*`.

## How the `.om` sources were made

A throwaway Python helper, not shipped, transcribed each original's body into omtex words, one Omega
`text` per paragraph. The preambles were written by hand. Every byte of LaTeX in the build output comes
from the Omega generator, and the helper is not part of the build.
