# Changesets

Every change that must ship a new `@pendle/core-v2` version needs a changeset. Run
`yarn changeset`, pick the bump type, and commit the generated file with your PR.

On merge to `main`, `.github/workflows/release.yml` opens or updates a
"Releasing vX.Y.Z" pull request. Merging that PR bumps `package.json`, updates
`CHANGELOG.md`, and publishes to npm with trusted publishing (OIDC). No npm
token exists anywhere in this flow.

For a snapshot build from a branch, comment `/snapshot-release` on the pull
request or run the Release workflow by hand. Snapshots publish under the
`nightly` dist-tag.
