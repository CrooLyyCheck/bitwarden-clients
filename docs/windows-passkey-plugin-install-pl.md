# Bitwarden Windows passkey plugin — testowy build

To nieoficjalny build z publicznego forka `CrooLyyCheck/bitwarden-clients`. Kod pluginu passkey
pochodzi z aktualnego upstreamu Bitwarden; fork domyślnie włącza eksperymentalną flagę i dodaje
weryfikowalny proces pakowania. Paczka AppX jest podpisana jednorazowym certyfikatem testowym,
który Windows nie uznaje automatycznie tak jak podpisu Microsoft Store.

## Pobranie i weryfikacja przed rozpakowaniem

Zainstaluj aktualny [GitHub CLI](https://cli.github.com/), a następnie dla tagu widocznego na stronie
wydania wykonaj:

```powershell
$repo = "CrooLyyCheck/bitwarden-clients"
$tag = Read-Host "Wklej tag widoczny na stronie wydania (passkey-plugin-v...-fork...)"
gh release download $tag -R $repo -p "Bitwarden-Passkey-Plugin-*-x64.zip"
$zip = Get-ChildItem "Bitwarden-Passkey-Plugin-*-x64.zip" | Select-Object -First 1

# Warstwa 1: plik jest dokładnie assetem niezmiennego release GitHub.
gh release verify-asset $tag $zip.FullName -R $repo

# Warstwa 2: plik powstał w publicznym workflow z kodu wskazanego przez tag.
gh attestation verify $zip.FullName -R $repo `
  --signer-workflow "$repo/.github/workflows/passkey-plugin-release.yml" `
  --source-ref "refs/tags/$tag" `
  --deny-self-hosted-runners
```

Obie komendy muszą zakończyć się powodzeniem. Attestation wiąże hash pobranego pliku z publicznym
workflow, repozytorium, tagiem i SHA źródła. Nie dowodzi, że kod jest wolny od błędów — dlatego w
release znajduje się również stały link do pełnego diffu względem upstreamu.

## Instalacja

1. Rozpakuj zweryfikowany ZIP.
2. Uruchom `Install-Bitwarden-PasskeyPlugin.cmd`.
3. Zaakceptuj UAC administratora.
4. Instalator ponownie sprawdzi sumy SHA-256 plików wewnątrz paczki, doda dołączony certyfikat do
   `LocalMachine\TrustedPeople` i zainstaluje AppX.
5. Uruchom Bitwarden z menu Start i odblokuj sejf.
6. Otwórz `ms-settings:passkeys-advancedoptions` i włącz Bitwarden na liście providerów.

Według dokumentacji Microsoft plugin passkey manager wymaga obecnie Windows 11 24H2, build
`26100.6725` lub nowszy, albo Windows 11 25H2, build `26200.6725` lub nowszy.

## Odinstalowanie

```powershell
Get-AppxPackage CrooLyyCheck.BitwardenPasskey | Remove-AppxPackage

Get-ChildItem Cert:\LocalMachine\TrustedPeople |
  Where-Object Subject -eq "CN=CrooLyyCheck Bitwarden Passkey Test" |
  Remove-Item
```

Certyfikat jest generowany od nowa dla każdego release. Po odinstalowaniu paczki usuń go z magazynu
`TrustedPeople`.
