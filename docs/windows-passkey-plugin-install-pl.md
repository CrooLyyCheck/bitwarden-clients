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
5. Uruchom zainstalowanego Bitwardena przynajmniej raz. Rejestracja providera passkey w Windows odbywa się przy starcie aplikacji, nie podczas samej instalacji AppX.

Skrypt robi dwie rzeczy: dodaje dołączony publiczny certyfikat `.cer` do `LocalMachine\TrustedPeople`, a następnie instaluje plik `.appx`.

## Instalacja ręczna

Uruchom PowerShell jako administrator w wyodrębnionym folderze i wykonaj:

```powershell
Import-Certificate -FilePath .\Bitwarden-Passkey-Test-Certificate.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople
Add-AppxPackage -Path .\Bitwarden-Passkey-Plugin-*-x64.appx -ForceApplicationShutdown -ForceUpdateFromAnyVersion
```

Jeśli Windows nadal blokuje sideloading, włącz **Settings → System → For developers → Developer Mode**, a potem powtórz instalację.

## Gdy Bitwarden nie pojawia się w ustawieniach passkey

Third-party passkey provider w Windows jest funkcją Preview. Na dzień 26 maja 2026 wymaga Windows 11 build `26100.6725` lub nowszego albo `26200.6725` lub nowszego.

Sprawdź wersję systemu:

```powershell
$v = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
"$($v.CurrentBuild).$($v.UBR)"
```

Sprawdź, czy paczka jest zainstalowana:

```powershell
Get-AppxPackage CrooLyyCheck.BitwardenPasskey
```

Po instalacji uruchom Bitwarden z menu Start i otwórz:

```powershell
start ms-settings:passkeys-advancedoptions
```

Na liście providerów powinien pojawić się **Bitwarden Desktop**. Jeśli go nie ma, zamknij Bitwarden, uruchom go ponownie i sprawdź log:

```powershell
$family = (Get-AppxPackage CrooLyyCheck.BitwardenPasskey).PackageFamilyName
Get-Content "$env:LOCALAPPDATA\Packages\$family\LocalCache\Roaming\Bitwarden\app.log" -Tail 80
```

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
