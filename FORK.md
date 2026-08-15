# Unofficial Windows passkey test build

This repository is a public fork of [bitwarden/clients](https://github.com/bitwarden/clients).
It is not maintained, reviewed, signed, or endorsed by Bitwarden, Inc.

## Exact upstream base

- Repository: `bitwarden/clients`
- Commit: [`51c7e4c650cec8d7f0cf53e297c484625ef5f210`](https://github.com/bitwarden/clients/commit/51c7e4c650cec8d7f0cf53e297c484625ef5f210)
- Fork release branch: `codex/windows-passkey-transparent-release`
- Exact comparison: [upstream base...fork branch](https://github.com/bitwarden/clients/compare/51c7e4c650cec8d7f0cf53e297c484625ef5f210...CrooLyyCheck:bitwarden-clients:codex/windows-passkey-transparent-release)

The machine-readable upstream commit is stored in [`.fork/upstream-commit`](.fork/upstream-commit).
Every release bundle also contains the upstream commit, fork commit, comparison URL, and Actions
run URL that produced it.

## Functional difference

The Windows native credential synchronization feature already exists in upstream. This fork makes
one functional change: `FeatureFlag.WindowsNativeCredentialSync` defaults to `true`, so the
experimental Windows passkey provider can be tested without a server-side feature-flag rollout.

All other fork-only files provide:

- the test AppX installer and installation notes;
- an immutable tag-based release workflow;
- SHA-256 checksums, an npm CycloneDX SBOM, and GitHub/Sigstore build attestations.

No new encryption logic is added. The passkey implementation itself remains the upstream code.

## Audit locally

```powershell
git fetch https://github.com/bitwarden/clients.git main
$upstream = (Get-Content .fork/upstream-commit).Trim()
git diff --stat "$upstream...HEAD"
git diff "$upstream...HEAD"
```

Release tags use `passkey-plugin-v<desktop-version>-fork.<revision>` and are never reused. Published
release assets and their tag are protected by GitHub immutable releases.
