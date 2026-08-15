# Bitwarden Windows passkey plugin — build from source

This is an unofficial fork at `CrooLyyCheck/bitwarden-clients`. The passkey plugin code comes from
upstream Bitwarden; the fork's only functional change enables the experimental Windows feature by
default.

The safest way to obtain the package is to build it yourself. You do not need to trust an
executable uploaded by the fork owner or use a paid CI service.

## Prerequisites

- Windows 11 x64;
- Git;
- Node.js `24.x` (the required version is also recorded in `.nvmrc`);
- stable Rust with the `x86_64-pc-windows-msvc` target;
- Visual Studio 2022 Build Tools with **Desktop development with C++**;
- the Windows 10 or 11 SDK, including `signtool.exe`;
- about 15 GB of free disk space.

## 1. Get the source

```powershell
git clone https://github.com/CrooLyyCheck/bitwarden-clients.git
cd bitwarden-clients
git switch --detach passkey-plugin-v2026.8.0-fork.4
```

Before building, you can inspect the complete diff against the recorded upstream commit:

```powershell
$upstream = (Get-Content .fork/upstream-commit).Trim()
git diff --stat "$upstream...HEAD"
git diff "$upstream...HEAD"
```

## 2. Check the prerequisites

This quick command checks your environment without building anything:

```powershell
.\BUILD-PASSKEY-PLUGIN.cmd -CheckOnly
```

## 3. Build the package

```powershell
.\BUILD-PASSKEY-PLUGIN.cmd
```

The script:

1. checks the tool versions and confirms that tracked Git files are clean;
2. confirms that the recorded upstream commit is an ancestor of the current commit;
3. runs `npm ci`, using the exact dependency versions from `package-lock.json`;
4. builds the native Rust plugin and the desktop application;
5. creates a one-time test certificate, signs the AppX, and removes the private key;
6. adds `SOURCE.json`, `SBOM.cdx.json`, and `SHA256SUMS.txt` to the ZIP.

The signature covers the complete AppX package, so Windows detects any change to a file inside it.
The inner EXE files are not signed separately; this means the build does not require Developer Mode
or permission to create symbolic links.

The result is written to:

```text
dist\passkey-plugin\Bitwarden-Passkey-Plugin-<version>-local.<commit>-x64.zip
```

A `.sha256.txt` file is created next to the ZIP. After downloading or copying the ZIP, verify it
without extracting it:

```powershell
$zip = Get-ChildItem .\dist\passkey-plugin\*.zip | Select-Object -First 1
$expected = (Get-Content "$($zip.FullName).sha256.txt").Split(' ')[0]
$actual = (Get-FileHash $zip.FullName -Algorithm SHA256).Hash
if ($actual -ne $expected) { throw "SHA-256 checksum mismatch" }
"SHA-256 verified: $actual"
```

For a later build, after `npm ci` has already completed successfully, you can save time with:

```powershell
.\BUILD-PASSKEY-PLUGIN.cmd -SkipNpmCi
```

A full build without this option is recommended for a package you intend to install.

## 4. Install the package

1. Extract the ZIP you built.
2. Run `Install-Bitwarden-PasskeyPlugin.cmd`.
3. Accept the administrator UAC prompt.
4. The installer verifies the SHA-256 checksums of every file, adds the included certificate to
   `LocalMachine\TrustedPeople`, and installs the AppX.
5. Start Bitwarden from the Start menu and unlock your vault.
6. Open `ms-settings:passkeys-advancedoptions` and enable Bitwarden in the provider list.

According to Microsoft documentation, a passkey manager plugin currently requires Windows 11 24H2
build `26100.6725` or later, or Windows 11 25H2 build `26200.6725` or later.

## Uninstall

```powershell
Get-AppxPackage CrooLyyCheck.BitwardenPasskey | Remove-AppxPackage

Get-ChildItem Cert:\LocalMachine\TrustedPeople |
  Where-Object Subject -eq "CN=CrooLyyCheck Bitwarden Passkey Test" |
  Remove-Item
```

A new certificate is generated for every local build. After uninstalling the package, remove its
certificate from the `TrustedPeople` store.
