# omtex (Omega library that writes LaTeX papers)

Shared rules: read https://www.aienos.com/agents/RULES.md first. This file adds what is specific to this
repository; where the two differ, this file wins here.

## Scope

- `lib/omtex.om`: the library. It is Omega; keep it Omega. Globals and texts starting with `z` and functions
  starting with `tx` are reserved for it, and papers must not use those names.
- `examples/*/paper.om`: papers. `tools/`: build, pin, compare and Zenodo draft scripts (sh).
  `tests/run.sh`: the suite. `evidence/`: measured outputs; never edit a recorded result.
- `docs/DESIGN.md` is the contract for escaping, the math check, listings and refusal codes. Change it
  in the same commit as the behaviour.

## Rules

- One compiler: `tools/pin.sh` names the omega-mv commit and omc sha256. Moving the pin means rerunning
  `tests/run.sh`, both reproductions (`tools/compare.sh`) and the keyword-parity test.
- Never loosen escaping, the math deny list or listing checks to make a paper build. Fix the paper
  source, or extend the library with a checked word and a refusal test (an accepted/refused pair).
- `tools/zenodo-draft.sh` must never publish. Do not add a publish path.
- omc limits seen here: error 12 means split the function (keep about 10 live names); a function
  takes at most 6 parameters (error 9); the library is an `om2` unit, where OM-2 words such as `at`
  are reserved (`fn f at ulong` is error 16 under `om2`, accepted without it).

## Commands

```sh
tools/build.sh examples/listings/paper.om build/listings
tests/run.sh
tools/compare.sh ORIG.tex ORIG.pdf build/X/paper.tex build/X/paper.pdf
```
