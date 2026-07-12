# jersey-tides

Harmonic tide predictions for St Helier, Jersey — a headless prediction engine
and a themeable React widget, plus the demo site that dogfoods them.

## Monorepo map

```
packages/
  core/    @u-b/tides-core   zero-dep harmonic engine + fitted St Helier station + almanac
  react/   @u-b/tides-react  'use client' TideWidget with the .ubtide theming contract
apps/
  demo/    the reference consumer site (deploys ub.je); depends on @u-b/tides-react
tools/
  fit/     harmonic refit pipeline + gates (private, not published)
```

pnpm workspaces; ESM-only; tsdown builds; changesets for versioning. `core` and
`react` are published to npm under the `@u-b` scope. `demo` and `fit-tools` are
private (ignored by changesets).

## Dev commands

```bash
pnpm install
pnpm dev          # run the demo site (apps/demo) locally
pnpm -r build     # build all packages
pnpm test         # run all package tests
pnpm typecheck    # tsc --noEmit across TS packages (excludes fit-tools)
pnpm fixtures     # regenerate golden fixtures
pnpm refit:check  # engine-move byte-identity gate
pnpm changeset    # author a changeset for a release
```

## Publishing

Releases are automated by [changesets](https://github.com/changesets/changesets)
and the `.github/workflows/release.yml` workflow, which publishes to npm with
**provenance via OIDC trusted publishing** (no long-lived `NPM_TOKEN`).

### Bootstrap sequence (one-time, per package)

CI can only take over once each package exists on npm and its trusted publisher
is registered — and a trusted publisher can't be registered for a package that
doesn't exist yet. So the first release is manual:

1. **Manual first publish.** As `otrebu`, from a clean tree:
   ```bash
   pnpm -r build
   pnpm -r publish --access public --provenance
   ```
   This creates `@u-b/tides-core@0.1.0` and `@u-b/tides-react@0.1.0` on npm.
2. **Configure the trusted publisher on npmjs.com, per package.** For *each* of
   `@u-b/tides-core` and `@u-b/tides-react`: Settings → Trusted Publishers → add
   GitHub Actions, repo `otrebu/jersey-tides`, workflow
   `.github/workflows/release.yml`, with the `publish` action ticked.
3. **CI takes over.** From then on, merge changesets to `main`; the release
   workflow opens/updates a Version PR and publishes when it merges. See the
   loud comment at the top of `release.yml` for the pnpm-version caveat.

## Contributing

Refit checklist, fixture-gate explanation, and the erasable-syntax contract are
in [CONTRIBUTING.md](./CONTRIBUTING.md).
