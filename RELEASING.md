# Releasing Herex

Releases are automated from conventional commits on `main`. The source tree remains at development version `0.0.0`; the release packager injects the semantic version into the staged `haxelib.json`.

The release workflow:

1. Re-runs formatting, tests, cross-target checks, secret scanning, and dependency audit.
2. Builds the Haxelib-compatible ZIP twice and requires identical bytes.
3. Installs the archive into an isolated Lix consumer that uses only `-lib herex`.
4. Creates a draft GitHub Release, uploads the ZIP and SHA-256 file, verifies them, then publishes the release.
5. Verifies the public versioned URL and checksum after publication.

Herex is not submitted to the Haxelib registry. The supported installation source is the immutable GitHub Release asset.

The public Lix smoke test rewrites GitHub API asset URLs from `github.com` to `www.github.com`. This is intentional: Lix 17 intercepts the bare host as a repository source and rejects Release asset paths before its generic HTTPS installer can handle them. Both hosts serve the same immutable GitHub asset.

Before a version-producing commit reaches `main`, update the version in README's Lix URL to the semantic version implied by the conventional commits since the last tag. The release prepare hook rejects a stale or speculative URL that does not equal `nextRelease.version`.

Package inputs must be Git-tracked regular files and exactly match `HEAD`. The packager rejects modified, deleted, or untracked content under its root-file manifest, `assets/`, and `src/` before it writes commit provenance.

Published `v*` tags and release assets are immutable. The reviewer-protected `release-repair` workflow may finish an incomplete draft for an existing protected tag; it must never move a tag, derive a new version, or replace a published asset.
