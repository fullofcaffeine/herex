# Releasing Herex

Releases are automated from conventional commits on `main`. The source tree remains at development version `0.0.0`; the release packager injects the semantic version into the staged `haxelib.json`.

The release workflow:

1. Re-runs formatting, tests, cross-target checks, secret scanning, and dependency audit.
2. Builds the Haxelib-compatible ZIP twice and requires identical bytes.
3. Installs the archive into an isolated Lix consumer that uses only `-lib herex`.
4. Creates a draft GitHub Release, uploads the ZIP and SHA-256 file, verifies them, then publishes the release.
5. Verifies the public versioned URL and checksum after publication.

Herex is not submitted to the Haxelib registry. The supported installation source is the immutable GitHub Release asset.

Published `v*` tags and release assets are immutable. The reviewer-protected `release-repair` workflow may finish an incomplete draft for an existing protected tag; it must never move a tag, derive a new version, or replace a published asset.
