# Security policy

## Reporting a vulnerability

Report privately. Do not open a public issue, pull request or discussion about it.

1. GitHub: open this repository's Security tab and choose "Report a vulnerability". This
   creates a private advisory that only the maintainers can see. If that option is not shown,
   private vulnerability reporting has not been enabled for this repository yet; use email.
2. Email: drake@aienos.com with the subject `[omtex] security report`.

Include the commit or release you tested, the component (path), steps to reproduce, and what an
attacker gains. If the report involves a secret, say where it was exposed and do not send the
secret itself. Encrypted mail is not required; do not post proof-of-concept payloads publicly.

## Response targets

This project has one maintainer; the targets below are best effort and stated honestly.

- Acknowledgement: within 3 working days.
- Triage and severity: within 7 days of acknowledgement.
- Fix or mitigation for confirmed issues: aim for 30 days for high and critical, 90 days
  otherwise, with a status update at least every 14 days until closed.
- Disclosure: coordinated. An advisory is published with credit (unless you ask otherwise)
  once the fix is on the default branch. Default embargo 90 days, negotiable.

## Scope

`omtex` is an Omega library (`lib/omtex.om`) for writing LaTeX papers. A paper is an Omega program
compiled together with the library; running it prints LaTeX, which `pdflatex` renders.
`tools/zenodo-draft.sh` uploads a built PDF to an unpublished Zenodo draft.

In scope:

- Prose text that reaches LaTeX unescaped, or math, `rawtex` or `preamble` text that passes the
  check in `docs/DESIGN.md` while using a control sequence that reads or writes files or changes
  category codes.
- A listing body that escapes its `lstlisting` environment.
- `paper.gen check OMC DIR` writing outside `DIR` or running something other than the given
  compiler.
- `tools/zenodo-draft.sh` publishing a record, leaking the token (it is meant to stay in a
  mode-600 header file, never in argv or output), or changing a record it should refuse.
- `tools/pin.sh` accepting a compiler other than the pinned sha256.

Out of scope:

- TeX Live, pdfTeX, Zenodo, the pinned compiler itself, and the host operating system.

## Supported versions

Only the default branch `main`; there is no release. Reports against older commits are welcome but fixes land on the default branch only.

## Status

No hosted CI workflow is tracked at this revision. No certification, no bug bounty. See AUDIT_SCOPE.md for what to review and how to build and test it.
