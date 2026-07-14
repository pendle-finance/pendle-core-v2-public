# CLAUDE.md

## Build / compile

Use `forge build` scoped to the directory you're working in, with `--via-ir` and `--sizes`:

```sh
forge build -C <subfolder> --sizes --via-ir
```

Example: `forge build -C contracts/pt-looping/ --sizes --via-ir`.

Prefer this over `npx hardhat compile` — it's faster, scoped, and reports contract sizes.
