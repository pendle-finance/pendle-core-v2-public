# CLAUDE.md

## Build / compile

Use `forge build` scoped to the directory you're working in, with `--via-ir` and `--sizes`:

```sh
forge build -C <subfolder> --sizes --via-ir
```

Example: `forge build -C contracts/pt-looping/ --sizes --via-ir`.

Prefer this over `npx hardhat compile` — it's faster, scoped, and reports contract sizes.

## Release

Publishing runs only from `.github/workflows/release.yml` with npm trusted
publishing. Do not run `yarn npm publish` by hand. Add a changeset
(`yarn changeset`) to any PR that must ship a new version; merging the
"Releasing vX.Y.Z" PR publishes. `/snapshot-release` on a PR publishes a
`nightly` snapshot. See `.changeset/README.md`.
