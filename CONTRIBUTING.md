# Contributing to Herex

Herex supports Haxe 4.3.7 and uses Lix for reproducible compiler and formatter setup.

```bash
npm ci
npm test
npm run format:check
```

Use `npm run format` before committing Haxe changes. Tests must include exact output assertions for successful syntax and a negative fixture for new diagnostics. Changes to syntax semantics should also update the README and package-consumer smoke test.

Commits use [Conventional Commits](https://www.conventionalcommits.org/) because releases are derived from the history on `main`.

- `fix:` produces a patch release.
- `feat:` produces a minor release.
- `feat!:` or a `BREAKING CHANGE:` footer produces a major release.

Do not commit generated output, local audit files, credentials, or package staging directories.
