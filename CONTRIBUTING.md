# Contributing

## Refit checklist (St Helier constituents)

The St Helier harmonic constants in
`packages/core/src/stations/st-helier.data.ts` are **fitted** to the States of
Jersey published tide tables. When you refit, follow this loop end to end:

1. **Fetch official events** into an `events.json` (array of `{ utc, height,
   type }`), see [MEMORY / data sources] for the gov.je endpoint.
2. **Fit** a new constituent set:
   ```bash
   node tools/fit/fit2.mjs events.json fit.json --train=all --beta=1.5 --iters=3
   ```
3. **Paste** the fitted `constituents` (and `datum` if it moved) into
   `packages/core/src/stations/st-helier.data.ts`.
4. **Compare** the new constants against the official events — record the height
   and timing mean/max:
   ```bash
   node tools/fit/compare2.mjs events.json
   ```
5. **Check far-window stability** vs the previous fit so you don't win near-term
   accuracy at the cost of long-horizon drift:
   ```bash
   node tools/fit/stability2.mjs old-fit.json fit.json 2027-01-01T00:00:00Z 365
   ```
6. **Regenerate fixtures** (this is what makes the fixture gate pass):
   ```bash
   pnpm fixtures
   ```
7. **Author a changeset** with the `compare2` numbers in the changelog body:
   ```bash
   pnpm changeset
   ```
   - **patch** if the new accuracy stays within the documented envelope
     (±5 min timing) — quote the numbers.
   - **minor** if accuracy moves beyond that envelope (behavior consumers can
     observe changes materially).
8. **Merge the Version PR** the release workflow opens; publish is automatic.

## Fixture gate

`packages/core` ships golden fixtures (`packages/core/fixtures/`) generated
deterministically by `pnpm fixtures` (seeded, no `Date.now`). A test asserts the
engine still reproduces them byte-for-byte.

**This means CI fails after any predictions-changing edit until you regenerate
and commit the fixtures.** That is intentional — it forces every constant/engine
change to be an explicit, reviewed fixture diff. Run `pnpm fixtures` and commit
the result as part of the same change.

## Erasable-syntax contract

Everything under `packages/*/src` and `tools/fit` is imported and run with
Node's native TypeScript type-stripping (no build step for the fit tools). Keep
the source **erasable**:

- No runtime TypeScript constructs: no `enum`, no parameter properties
  (`constructor(private x)`), no namespaces with runtime members.
- Type-only imports/exports use `import type` / `export type`.
- Intra-package relative imports carry the **explicit `.ts` extension**
  (e.g. `import { createStation } from './station.ts'`), because these files run
  unbundled under Node.

`packages/core` sets `erasableSyntaxOnly: true` in its tsconfig, so
non-erasable syntax fails typecheck there. `verbatimModuleSyntax` and
`allowImportingTsExtensions` are on across the workspace to keep the type-only
imports and explicit `.ts` extensions honest.
