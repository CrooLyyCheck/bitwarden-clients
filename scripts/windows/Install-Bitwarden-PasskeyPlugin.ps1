#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$PackagePath,
    [string]$CertificatePath
)

$ErrorActionPreference = "Stop"
$expectedPublisher = "CN=CrooLyyCheck Bitwarden Passkey Test"

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Join-QuotedArgument {
    param([string]$Value)
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Test-BundleChecksums {
    param([string]$BundleDirectory)

    $checksumPath = Join-Path $BundleDirectory "SHA256SUMS.txt"
    if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
        throw "Brak pliku SHA256SUMS.txt. Najpierw zweryfikuj i ponownie pobierz pełną paczkę release."
    }

    foreach ($line in Get-Content -LiteralPath $checksumPath) {
        if ($line -notmatch '^([A-Fa-f0-9]{64})  ([^\\/]+)$') {
            throw "Nieprawidłowy wpis w SHA256SUMS.txt: $line"
        }

        $expectedHash = $Matches[1].ToUpperInvariant()
        $filePath = Join-Path $BundleDirectory $Matches[2]
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            throw "Brak pliku wymienionego w SHA256SUMS.txt: $($Matches[2])"
        }

        $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash
        if ($actualHash -ne $expectedHash) {
            throw "Niezgodna suma SHA-256 pliku $($Matches[2]). Nie instaluj tej paczki."
        }
    }
}

if (-not (Test-Administrator)) {
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-QuotedArgument $PSCommandPath)
    )

    if ($PackagePath) {
        $arguments += "-PackagePath"
        $arguments += (Join-QuotedArgument $PackagePath)
    }

    if ($CertificatePath) {
        $arguments += "-CertificatePath"
        $arguments += (Join-QuotedArgument $CertificatePath)
    }

    Start-Process -FilePath "PowerShell.exe" -ArgumentList $arguments -Verb RunAs
    exit
}

$scriptDirectory = Split-Path -Parent $PSCommandPath
Test-BundleChecksums -BundleDirectory $scriptDirectory

if (-not $PackagePath) {
    $package = Get-ChildItem -LiteralPath $scriptDirectory -Filter "Bitwarden-Passkey-Plugin-*-x64.appx" -File |
        Select-Object -First 1

    if ($null -eq $package) {
        throw "Nie znaleziono paczki AppX w folderze $scriptDirectory"
    }

    $PackagePath = $package.FullName
}

if (-not $CertificatePath) {
    $certificate = Get-ChildItem -LiteralPath $scriptDirectory -Filter "Bitwarden-Passkey-Test-Certificate.cer" -File |
        Select-Object -First 1

    if ($null -eq $certificate) {
        throw "Nie znaleziono certyfikatu testowego w folderze $scriptDirectory"
    }

    $CertificatePath = $certificate.FullName
}

$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$CertificatePath = (Resolve-Path -LiteralPath $CertificatePath).Path
$certificate = Get-PfxCertificate -FilePath $CertificatePath

if ($certificate.Subject -ne $expectedPublisher) {
    throw "Nieoczekiwany wystawca certyfikatu: $($certificate.Subject). Nie instaluj tej paczki."
}

Write-Host "Sumy SHA-256 paczki są poprawne." -ForegroundColor Green
Write-Host "Certyfikat: $CertificatePath"
Write-Host "Pakiet:      $PackagePath"
Write-Host "Odcisk:      $($certificate.Thumbprint)"
Write-Host ""

Unblock-File -LiteralPath $CertificatePath -ErrorAction SilentlyContinue
Unblock-File -LiteralPath $PackagePath -ErrorAction SilentlyContinue

Write-Host "Dodawanie jednorazowego certyfikatu release do LocalMachine\\TrustedPeople..."
Import-Certificate -FilePath $CertificatePath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople" | Out-Null

Write-Host "Instalowanie AppX..."
Add-AppxPackage -Path $PackagePath -ForceApplicationShutdown -ForceUpdateFromAnyVersion

Write-Host ""
Write-Host "Gotowe. Uruchom Bitwarden z menu Start." -ForegroundColor Green
