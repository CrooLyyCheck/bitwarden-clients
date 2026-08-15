# Bitwarden Windows passkey plugin — build ze źródła

To nieoficjalny fork `CrooLyyCheck/bitwarden-clients`. Kod pluginu passkey pochodzi z upstreamu
Bitwarden; jedyna zmiana funkcjonalna forka domyślnie włącza eksperymentalną funkcję Windows.

Najbezpieczniejszy sposób uzyskania paczki to zbudowanie jej samodzielnie. Nie trzeba ufać
plikowi wykonywalnemu przesłanemu przez właściciela forka ani korzystać z płatnej usługi CI.

## Wymagania

- Windows 11 x64;
- Git;
- Node.js `24.x` (wersja jest również zapisana w `.nvmrc`);
- Rust stable z toolchainem `x86_64-pc-windows-msvc`;
- Visual Studio 2022 Build Tools z opcją **Desktop development with C++**;
- Windows 10 lub 11 SDK, zawierający `signtool.exe`;
- około 15 GB wolnego miejsca.

## 1. Pobranie źródła

```powershell
git clone https://github.com/CrooLyyCheck/bitwarden-clients.git
cd bitwarden-clients
git switch codex/windows-passkey-transparent-release
```

Przed budowaniem można wyświetlić pełną różnicę względem zapisanego upstreamu:

```powershell
$upstream = (Get-Content .fork/upstream-commit).Trim()
git diff --stat "$upstream...HEAD"
git diff "$upstream...HEAD"
```

## 2. Sprawdzenie wymagań

Ta szybka komenda niczego nie buduje:

```powershell
.\BUILD-PASSKEY-PLUGIN.cmd -CheckOnly
```

## 3. Zbudowanie paczki

```powershell
.\BUILD-PASSKEY-PLUGIN.cmd
```

Skrypt kolejno:

1. sprawdza wersje narzędzi i czystość śledzonych plików Git;
2. potwierdza, że zapisany commit upstreamu jest przodkiem bieżącego commita;
3. wykonuje `npm ci`, więc używa dokładnych wersji z `package-lock.json`;
4. buduje natywny plugin Rust i aplikację desktopową;
5. tworzy jednorazowy certyfikat testowy, podpisuje AppX i usuwa prywatny klucz;
6. dodaje do ZIP-a `SOURCE.json`, `SBOM.cdx.json` i `SHA256SUMS.txt`.

Podpis obejmuje cały pakiet AppX, więc Windows wykryje każdą zmianę pliku wewnątrz paczki.
Wewnętrzne pliki EXE nie są podpisywane osobno; dzięki temu build nie wymaga trybu deweloperskiego
ani uprawnień do tworzenia dowiązań symbolicznych.

Wynik znajduje się w:

```text
dist\passkey-plugin\Bitwarden-Passkey-Plugin-<wersja>-local.<commit>-x64.zip
```

Obok powstaje plik `.sha256.txt`. Po ponownym pobraniu lub skopiowaniu ZIP-a można sprawdzić go
bez rozpakowywania:

```powershell
$zip = Get-ChildItem .\dist\passkey-plugin\*.zip | Select-Object -First 1
$expected = (Get-Content "$($zip.FullName).sha256.txt").Split(' ')[0]
$actual = (Get-FileHash $zip.FullName -Algorithm SHA256).Hash
if ($actual -ne $expected) { throw "Niezgodna suma SHA-256" }
"SHA-256 poprawne: $actual"
```

Przy kolejnym buildzie po poprawnym `npm ci` można oszczędzić czas:

```powershell
.\BUILD-PASSKEY-PLUGIN.cmd -SkipNpmCi
```

Pełny build bez tej opcji jest zalecany do paczki przeznaczonej do instalacji.

## 4. Instalacja

1. Rozpakuj zbudowany ZIP.
2. Uruchom `Install-Bitwarden-PasskeyPlugin.cmd`.
3. Zaakceptuj UAC administratora.
4. Instalator sprawdzi sumy SHA-256 wszystkich plików, doda dołączony certyfikat do
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

Certyfikat jest generowany od nowa dla każdego lokalnego builda. Po odinstalowaniu paczki usuń go
z magazynu `TrustedPeople`.
