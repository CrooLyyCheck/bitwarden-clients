# Unofficial Windows passkey test build

This repository is a public fork of [bitwarden/clients](https://github.com/bitwarden/clients).
It is not maintained, reviewed, signed, or endorsed by Bitwarden, Inc.

## Exact upstream base

- Repository: `bitwarden/clients`
- Commit: [`51c7e4c650cec8d7f0cf53e297c484625ef5f210`](https://github.com/bitwarden/clients/commit/51c7e4c650cec8d7f0cf53e297c484625ef5f210)
- Fork release branch: `codex/windows-passkey-transparent-release`
- Exact comparison: [upstream base...fork branch](https://github.com/bitwarden/clients/compare/51c7e4c650cec8d7f0cf53e297c484625ef5f210...CrooLyyCheck:bitwarden-clients:codex/windows-passkey-transparent-release)

The machine-readable upstream commit is stored in [`.fork/upstream-commit`](.fork/upstream-commit).
Every locally built bundle also contains the upstream commit, fork commit, comparison URL, tool
versions, SHA-256 checksums, and an npm CycloneDX SBOM.

## Functional difference

The Windows native credential synchronization feature already exists in upstream. This fork makes
one functional change: `FeatureFlag.WindowsNativeCredentialSync` defaults to `true`, so the
experimental Windows passkey provider can be tested without a server-side feature-flag rollout.

All other fork-only files provide:

- a one-command local Windows build;
- an isolated Electron packaging configuration for the unofficial AppX identity;
- the test AppX installer and Polish build/installation notes;
- SHA-256 checksums, an npm CycloneDX SBOM, and exact source metadata.

No new encryption logic is added. The passkey implementation itself remains the upstream code.

## Build locally on Windows

After installing the prerequisites described in
[`docs/windows-passkey-plugin-install-pl.md`](docs/windows-passkey-plugin-install-pl.md), run from
the repository root:

```powershell
.\BUILD-PASSKEY-PLUGIN.cmd
```

The ZIP and its outer SHA-256 checksum are written to `dist/passkey-plugin`. The script refuses to
build when tracked source files have uncommitted changes, validates the recorded upstream commit,
uses `npm ci`, creates a temporary test-signing certificate, and removes its private key after the
package is built.

## Audit locally

```powershell
git fetch https://github.com/bitwarden/clients.git main
$upstream = (Get-Content .fork/upstream-commit).Trim()
git diff --stat "$upstream...HEAD"
git diff "$upstream...HEAD"
```

Source tags use `passkey-plugin-v<desktop-version>-fork.<revision>` and are never reused. A local
build records the exact tag commit in `SOURCE.json`; binaries do not need to be downloaded from or
trusted from a separate hosting service.
