#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$PackagePath,
    [string]$CertificatePath
)

$ErrorActionPreference = "Stop"

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Join-QuotedArgument {
    param([string]$Value)
    return '"' + $Value.Replace('"', '\"') + '"'
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

if (-not $PackagePath) {
    $package = Get-ChildItem -Path $scriptDirectory -Filter "Bitwarden-Passkey-Plugin-*-x64.appx" -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -eq $package) {
        throw "Nie znaleziono pliku Bitwarden-Passkey-Plugin-*-x64.appx w folderze $scriptDirectory"
    }

    $PackagePath = $package.FullName
}

if (-not $CertificatePath) {
    $certificate = Get-ChildItem -Path $scriptDirectory -Filter "Bitwarden-Passkey-Test-Certificate.cer" -File |
        Select-Object -First 1

    if ($null -eq $certificate) {
        throw "Nie znaleziono pliku Bitwarden-Passkey-Test-Certificate.cer w folderze $scriptDirectory"
    }

    $CertificatePath = $certificate.FullName
}

$PackagePath = (Resolve-Path $PackagePath).Path
$CertificatePath = (Resolve-Path $CertificatePath).Path

Write-Host "Instalowanie testowego builda Bitwarden z Windows passkey plugin support." -ForegroundColor Cyan
Write-Host "Certyfikat: $CertificatePath"
Write-Host "Pakiet:      $PackagePath"
Write-Host ""

Unblock-File -Path $CertificatePath -ErrorAction SilentlyContinue
Unblock-File -Path $PackagePath -ErrorAction SilentlyContinue

Write-Host "Dodawanie certyfikatu do LocalMachine\\TrustedPeople..."
Import-Certificate -FilePath $CertificatePath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople" | Out-Null

Write-Host "Instalowanie AppX..."
Add-AppxPackage -Path $PackagePath -ForceApplicationShutdown -ForceUpdateFromAnyVersion

Write-Host ""
Write-Host "Gotowe. Uruchom Bitwarden z menu Start." -ForegroundColor Green
