# CLAUDE.md

## Build / compile

Use `forge build` scoped to the directory you're working in. `foundry.toml` turns on `via_ir` and the optimizer:

```sh
forge build -C <subfolder> --sizes
```

Example: `forge build -C contracts/pt-looping/ --sizes`.

Prefer this over `npx hardhat compile` — it's faster, scoped, and reports contract sizes.

## Release

Publishing runs only from `.github/workflows/release.yml` with npm trusted
publishing. Do not run `yarn npm publish` by hand. Add a changeset
(`yarn changeset`) to any PR that must ship a new version; merging the
"Releasing vX.Y.Z" PR publishes. `/snapshot-release` on a PR publishes a
`nightly` snapshot. See `.changeset/README.md`.
