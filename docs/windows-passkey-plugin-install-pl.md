# Bitwarden Windows passkey plugin - instalacja testowego builda

Ten build jest nieoficjalny i pochodzi z forka `CrooLyyCheck/clients`. Paczka AppX jest podpisana testowym certyfikatem self-signed, dlatego Windows nie zaufa jej automatycznie tak jak aplikacji ze sklepu Microsoft Store.

## Pobieranie

1. Wejdź w release forka: <https://github.com/CrooLyyCheck/clients/releases/tag/passkey-plugin-latest>
2. Pobierz plik `Bitwarden-Passkey-Plugin-*-x64.zip`.
3. Kliknij plik prawym przyciskiem i wybierz **Extract All / Wyodrębnij wszystko**.

## Najprostsza instalacja

1. Otwórz wyodrębniony folder.
2. Uruchom `Install-Bitwarden-PasskeyPlugin.cmd`.
3. Zaakceptuj okno UAC administratora.
4. Poczekaj na komunikat `Gotowe. Uruchom Bitwarden z menu Start.`

Skrypt robi dwie rzeczy: dodaje dołączony publiczny certyfikat `.cer` do `LocalMachine\TrustedPeople`, a następnie instaluje plik `.appx`.

## Instalacja ręczna

Uruchom PowerShell jako administrator w wyodrębnionym folderze i wykonaj:

```powershell
Import-Certificate -FilePath .\Bitwarden-Passkey-Test-Certificate.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople
Add-AppxPackage -Path .\Bitwarden-Passkey-Plugin-*-x64.appx
```

Jeśli Windows nadal blokuje sideloading, włącz **Settings → System → For developers → Developer Mode**, a potem powtórz instalację.

## Komunikat 0x800B0109

`0x800B0109` oznacza, że Windows nie ufa certyfikatowi podpisującemu AppX. Rozwiązaniem jest import pliku `Bitwarden-Passkey-Test-Certificate.cer` do magazynu `LocalMachine\TrustedPeople`, co robi dołączony instalator.

## Odinstalowanie

Usuń aplikację:

```powershell
Get-AppxPackage CrooLyyCheck.BitwardenPasskey | Remove-AppxPackage
```

Usuń testowy certyfikat:

```powershell
Get-ChildItem Cert:\LocalMachine\TrustedPeople |
  Where-Object Subject -eq "CN=CrooLyyCheck Bitwarden Passkey Test" |
  Remove-Item
```

Instaluj ten build tylko wtedy, gdy ufasz temu forkowi i konkretnemu release. Dodanie certyfikatu do `TrustedPeople` pozwala Windowsowi instalować pakiety podpisane tym certyfikatem.
