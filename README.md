# Nieoficjalny fork: plugin passkey dla Windows

> [!WARNING]
> To nie jest oficjalne wydanie Bitwarden. Kod pluginu pochodzi z upstreamu, a fork domyślnie
> włącza eksperymentalną funkcję Windows. Dokładny opis zmian znajduje się w [FORK.md](FORK.md).

## Zbuduj paczkę samodzielnie

Nie musisz pobierać ani ufać gotowej binarce. Na Windows sklonuj repozytorium, wybierz niezmienny
tag źródłowy i uruchom jedną komendę:

```powershell
git clone https://github.com/CrooLyyCheck/bitwarden-clients.git
cd bitwarden-clients
git switch --detach passkey-plugin-v2026.8.0-fork.3

.\BUILD-PASSKEY-PLUGIN.cmd -CheckOnly
.\BUILD-PASSKEY-PLUGIN.cmd
```

Gotowy ZIP i jego suma SHA-256 pojawią się w `dist\passkey-plugin`. Paczka zawiera również
`SOURCE.json` z dokładnymi commitami, SBOM CycloneDX i sumy wszystkich plików. Skrypt używa wersji
z `package-lock.json`, podpisuje cały AppX jednorazowym certyfikatem testowym i usuwa prywatny klucz
po zakończeniu.

Przed rozpoczęciem zainstaluj narzędzia wymienione w
[polskiej instrukcji budowania i instalacji](docs/windows-passkey-plugin-install-pl.md). Możesz też
zobaczyć [pełną różnicę względem oryginalnego repozytorium](https://github.com/bitwarden/clients/compare/51c7e4c650cec8d7f0cf53e297c484625ef5f210...CrooLyyCheck%3Abitwarden-clients%3Amain).

---

## Oryginalna dokumentacja Bitwarden

<p align="center">
  <img src="https://raw.githubusercontent.com/bitwarden/brand/main/screenshots/apps-combo-logo.png" alt="Bitwarden" />
</p>
<p align="center">
  <a href="https://github.com/bitwarden/clients/actions/workflows/build-browser.yml?query=branch:main" target="_blank"><img src="https://github.com/bitwarden/clients/actions/workflows/build-browser.yml/badge.svg?branch=main" alt="GitHub Workflow browser build on main" /></a>
  <a href="https://github.com/bitwarden/clients/actions/workflows/build-cli.yml?query=branch:main" target="_blank"><img src="https://github.com/bitwarden/clients/actions/workflows/build-cli.yml/badge.svg?branch=main" alt="GitHub Workflow CLI build on main" /></a>
  <a href="https://github.com/bitwarden/clients/actions/workflows/build-desktop.yml?query=branch:main" target="_blank"><img src="https://github.com/bitwarden/clients/actions/workflows/build-desktop.yml/badge.svg?branch=main" alt="GitHub Workflow desktop build on main" /></a>
  <a href="https://github.com/bitwarden/clients/actions/workflows/build-web.yml?query=branch:main" target="_blank"><img src="https://github.com/bitwarden/clients/actions/workflows/build-web.yml/badge.svg?branch=main" alt="GitHub Workflow web build on main" /></a>
</p>

---

# Bitwarden Client Applications

This repository houses all Bitwarden client applications except the mobile applications ([iOS](https://github.com/bitwarden/ios) | [android](https://github.com/bitwarden/android)).

Please refer to the [Clients section](https://contributing.bitwarden.com/getting-started/clients/) of the [Contributing Documentation](https://contributing.bitwarden.com/) for build instructions, recommended tooling, code style tips, and lots of other great information to get you started.

## Related projects:

- [bitwarden/server](https://github.com/bitwarden/server): The core infrastructure backend (API, database, Docker, etc).
- [bitwarden/ios](https://github.com/bitwarden/ios): Bitwarden iOS Password Manager & Authenticator apps.
- [bitwarden/android](https://github.com/bitwarden/android): Bitwarden Android Password Manager & Authenticator apps.
- [bitwarden/directory-connector](https://github.com/bitwarden/directory-connector): A tool for syncing a directory (AD, LDAP, Azure, G Suite, Okta) to an organization.

# We're Hiring!

Interested in contributing in a big way? Consider joining our team! We're hiring for many positions. Please take a look at our [Careers page](https://bitwarden.com/careers/) to see what opportunities are [currently open](https://bitwarden.com/careers/#open-positions) as well as what it's like to work at Bitwarden.

# Contribute

Code contributions are welcome! Please commit any pull requests against the `main` branch. Learn more about how to contribute by reading the [Contributing Guidelines](https://contributing.bitwarden.com/contributing/). Check out the [Contributing Documentation](https://contributing.bitwarden.com/) for how to get started with your first contribution.

Security audits and feedback are welcome. Please open an issue or email us privately if the report is sensitive in nature. You can read our security policy in the [`SECURITY.md`](SECURITY.md) file.
