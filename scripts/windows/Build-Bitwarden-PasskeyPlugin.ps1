#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [ValidateRange(0, 65535)]
    [int]$BuildNumber = 1,
    [switch]$SkipNpmCi,
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDirectory = Split-Path -Parent $PSCommandPath
$repositoryRoot = (Resolve-Path (Join-Path $scriptDirectory "..\..")).Path
$desktopDirectory = Join-Path $repositoryRoot "apps\desktop"
$nativeDirectory = Join-Path $desktopDirectory "desktop_native"

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repositoryRoot "dist\passkey-plugin"
} elseif (-not [IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot $OutputDirectory
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )

    Push-Location $WorkingDirectory
    try {
        & $Command @Arguments
        if ($LASTEXITCODE -ne 0) {
            $joinedArguments = $Arguments -join " "
            throw "Polecenie '$Command $joinedArguments' zakonczylo sie kodem $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
}

function Get-CommandOutput {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )

    Push-Location $WorkingDirectory
    try {
        $output = & $Command @Arguments
        if ($LASTEXITCODE -ne 0) {
            $joinedArguments = $Arguments -join " "
            throw "Polecenie '$Command $joinedArguments' zakonczylo sie kodem $LASTEXITCODE."
        }
        return ($output -join "`n").Trim()
    } finally {
        Pop-Location
    }
}

if ($env:OS -ne "Windows_NT") {
    throw "Ten skrypt buduje testowy AppX i musi zostac uruchomiony w Windows."
}

$requiredCommands = @("git", "node", "npm", "npx", "cargo", "rustc")
foreach ($requiredCommand in $requiredCommands) {
    if (-not (Get-Command $requiredCommand -ErrorAction SilentlyContinue)) {
        throw "Brak polecenia '$requiredCommand'. Zobacz docs/windows-passkey-plugin-install-pl.md."
    }
}

foreach ($requiredPowerShellCommand in @(
    "New-SelfSignedCertificate",
    "Export-PfxCertificate",
    "Export-Certificate"
)) {
    if (-not (Get-Command $requiredPowerShellCommand -ErrorAction SilentlyContinue)) {
        throw "Brak polecenia '$requiredPowerShellCommand'. Wymagany jest modul PKI systemu Windows."
    }
}

$windowsKits = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
$signTool = Get-ChildItem -LiteralPath $windowsKits -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
    Sort-Object FullName -Descending |
    Select-Object -First 1

if ($null -eq $signTool) {
    throw "Nie znaleziono signtool.exe. Zainstaluj Windows 10/11 SDK z Visual Studio Build Tools."
}

$expectedNodeMajor = ((Get-Content -LiteralPath (Join-Path $repositoryRoot ".nvmrc")).Trim() -replace '^v', '')
$actualNodeVersion = (Get-CommandOutput -Command "node" -Arguments @("--version") -WorkingDirectory $repositoryRoot) -replace '^v', ''
$actualNodeMajor = $actualNodeVersion.Split('.')[0]
if ($actualNodeMajor -ne $expectedNodeMajor) {
    throw "Repozytorium wymaga Node $expectedNodeMajor.x, a aktywna wersja to $actualNodeVersion."
}

$trackedChanges = Get-CommandOutput -Command "git" -Arguments @("status", "--porcelain", "--untracked-files=no") -WorkingDirectory $repositoryRoot
if ($trackedChanges) {
    throw "Drzewo Git zawiera niezatwierdzone zmiany sledzonych plikow. Zacommituj je albo uzyj czystego klona przed budowaniem."
}

$forkCommit = Get-CommandOutput -Command "git" -Arguments @("rev-parse", "HEAD") -WorkingDirectory $repositoryRoot
$shortCommit = Get-CommandOutput -Command "git" -Arguments @("rev-parse", "--short=12", "HEAD") -WorkingDirectory $repositoryRoot
$upstreamCommit = (Get-Content -LiteralPath (Join-Path $repositoryRoot ".fork\upstream-commit")).Trim()
Invoke-ExternalCommand -Command "git" -Arguments @("cat-file", "-e", "$upstreamCommit^{commit}") -WorkingDirectory $repositoryRoot
Invoke-ExternalCommand -Command "git" -Arguments @("merge-base", "--is-ancestor", $upstreamCommit, $forkCommit) -WorkingDirectory $repositoryRoot

$packageVersion = (Get-Content -Raw -LiteralPath (Join-Path $desktopDirectory "package.json") | ConvertFrom-Json).version
$npmVersion = Get-CommandOutput -Command "npm" -Arguments @("--version") -WorkingDirectory $repositoryRoot
$rustVersion = Get-CommandOutput -Command "rustc" -Arguments @("--version") -WorkingDirectory $repositoryRoot

Write-Host "Zrodlo:    $forkCommit"
Write-Host "Upstream:  $upstreamCommit"
Write-Host "Node:      $actualNodeVersion (wymagane $expectedNodeMajor.x)"
Write-Host "npm:       $npmVersion"
Write-Host "Rust:      $rustVersion"
Write-Host "Wyjscie:   $OutputDirectory"

if ($CheckOnly) {
    Write-Host "Sprawdzenie wymagan zakonczone powodzeniem." -ForegroundColor Green
    exit 0
}

$temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ("bitwarden-passkey-build-" + [guid]::NewGuid().ToString("N"))
$signingDirectory = Join-Path $temporaryDirectory "signing"
$bundleDirectory = Join-Path $temporaryDirectory "bundle"
New-Item -ItemType Directory -Force -Path $signingDirectory, $bundleDirectory | Out-Null

$certificate = $null
$certificatePassword = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
$originalPath = $env:PATH
$originalBuildNumber = $env:BUILD_NUMBER
$originalSignToolPath = $env:SIGNTOOL_PATH
$originalSignCertificate = $env:ELECTRON_BUILDER_SIGN_CERT
$originalSignCertificatePassword = $env:ELECTRON_BUILDER_SIGN_CERT_PW
$buildStartedAt = Get-Date

try {
    if (-not $SkipNpmCi) {
        Write-Host "`n[1/5] Instalowanie zaleznosci z package-lock.json..." -ForegroundColor Cyan
        Invoke-ExternalCommand -Command "npm" -Arguments @("ci") -WorkingDirectory $repositoryRoot
    } else {
        Write-Host "`n[1/5] Pominieto npm ci (-SkipNpmCi)." -ForegroundColor Yellow
    }

    Write-Host "`n[2/5] Budowanie natywnego modulu i pluginu Windows..." -ForegroundColor Cyan
    Invoke-ExternalCommand `
        -Command "node" `
        -Arguments @("build.js", "--target=x86_64-pc-windows-msvc", "--release") `
        -WorkingDirectory $nativeDirectory

    Write-Host "`n[3/5] Budowanie aplikacji desktopowej..." -ForegroundColor Cyan
    Invoke-ExternalCommand -Command "npm" -Arguments @("run", "build") -WorkingDirectory $desktopDirectory

    Write-Host "`n[4/5] Tworzenie jednorazowego certyfikatu i pakietu AppX..." -ForegroundColor Cyan
    $certificate = New-SelfSignedCertificate `
        -Type Custom `
        -KeyAlgorithm RSA `
        -KeyLength 3072 `
        -KeyUsage DigitalSignature `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy Exportable `
        -HashAlgorithm SHA256 `
        -Subject "CN=CrooLyyCheck Bitwarden Passkey Test" `
        -FriendlyName "CrooLyyCheck Bitwarden Passkey Local Test Signing" `
        -NotAfter (Get-Date).AddMonths(18) `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")

    $securePassword = ConvertTo-SecureString $certificatePassword -AsPlainText -Force
    $pfxPath = Join-Path $signingDirectory "passkey-signing.pfx"
    $cerPath = Join-Path $signingDirectory "Bitwarden-Passkey-Test-Certificate.cer"
    Export-PfxCertificate `
        -Cert "Cert:\CurrentUser\My\$($certificate.Thumbprint)" `
        -FilePath $pfxPath `
        -Password $securePassword | Out-Null
    Export-Certificate `
        -Cert "Cert:\CurrentUser\My\$($certificate.Thumbprint)" `
        -FilePath $cerPath | Out-Null

    $env:PATH = "$(Split-Path $signTool.FullName);$originalPath"
    $env:BUILD_NUMBER = $BuildNumber
    $env:SIGNTOOL_PATH = $signTool.FullName
    $env:ELECTRON_BUILDER_SIGN_CERT = $pfxPath
    $env:ELECTRON_BUILDER_SIGN_CERT_PW = $certificatePassword

    $electronBuilderArguments = @(
        "electron-builder",
        "--config", "electron-builder.passkey.json",
        "--win", "appx",
        "--x64",
        "--publish", "never"
    )
    Invoke-ExternalCommand -Command "npx" -Arguments $electronBuilderArguments -WorkingDirectory $desktopDirectory

    $builtAppx = Get-ChildItem -LiteralPath (Join-Path $desktopDirectory "dist") `
        -Filter "Bitwarden-Passkey-Plugin-*-x64.appx" `
        -Recurse `
        -File |
        Where-Object { $_.LastWriteTime -ge $buildStartedAt } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $builtAppx) {
        throw "Nie znaleziono swiezo zbudowanego pakietu AppX."
    }

    Write-Host "`n[5/5] Tworzenie paczki, SBOM i sum SHA-256..." -ForegroundColor Cyan
    $releaseVersion = "$packageVersion-local.$shortCommit"
    $appxName = "Bitwarden-Passkey-Plugin-$releaseVersion-x64.appx"
    Copy-Item -LiteralPath $builtAppx.FullName -Destination (Join-Path $bundleDirectory $appxName)
    Copy-Item -LiteralPath $cerPath -Destination $bundleDirectory
    Copy-Item -LiteralPath (Join-Path $scriptDirectory "Install-Bitwarden-PasskeyPlugin.ps1") -Destination $bundleDirectory
    Copy-Item -LiteralPath (Join-Path $scriptDirectory "Install-Bitwarden-PasskeyPlugin.cmd") -Destination $bundleDirectory
    Copy-Item `
        -LiteralPath (Join-Path $repositoryRoot "docs\windows-passkey-plugin-install-pl.md") `
        -Destination (Join-Path $bundleDirectory "README-INSTALL-PL.md")

    Push-Location $repositoryRoot
    try {
        $sbom = & npm sbom --package-lock-only --workspace "@bitwarden/desktop" --omit dev --sbom-format cyclonedx
        if ($LASTEXITCODE -ne 0) {
            throw "Generowanie SBOM zakonczylo sie kodem $LASTEXITCODE."
        }
        $sbom | Set-Content -LiteralPath (Join-Path $bundleDirectory "SBOM.cdx.json") -Encoding UTF8
    } finally {
        Pop-Location
    }

    $sourceInformation = [ordered]@{
        buildType = "local-windows"
        forkRepository = "https://github.com/CrooLyyCheck/bitwarden-clients"
        forkCommit = $forkCommit
        forkCommitUrl = "https://github.com/CrooLyyCheck/bitwarden-clients/commit/$forkCommit"
        upstreamRepository = "https://github.com/bitwarden/clients"
        upstreamCommit = $upstreamCommit
        compareUrl = "https://github.com/bitwarden/clients/compare/$upstreamCommit...CrooLyyCheck:bitwarden-clients:$forkCommit"
        nodeVersion = $actualNodeVersion
        npmVersion = $npmVersion
        rustVersion = $rustVersion
        buildNumber = $BuildNumber
    }
    $sourceInformation |
        ConvertTo-Json |
        Set-Content -LiteralPath (Join-Path $bundleDirectory "SOURCE.json") -Encoding UTF8

    Get-ChildItem -LiteralPath $bundleDirectory -File |
        Get-FileHash -Algorithm SHA256 |
        Sort-Object Path |
        ForEach-Object { "$($_.Hash)  $([IO.Path]::GetFileName($_.Path))" } |
        Set-Content -LiteralPath (Join-Path $bundleDirectory "SHA256SUMS.txt") -Encoding ASCII

    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
    $zipName = "Bitwarden-Passkey-Plugin-$releaseVersion-x64.zip"
    $zipPath = Join-Path $OutputDirectory $zipName
    Compress-Archive -Path (Join-Path $bundleDirectory "*") -DestinationPath $zipPath -Force

    $zipHash = Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
    $outerChecksumPath = "$zipPath.sha256.txt"
    "$($zipHash.Hash)  $zipName" | Set-Content -LiteralPath $outerChecksumPath -Encoding ASCII

    Write-Host "`nGotowe." -ForegroundColor Green
    Write-Host "Paczka: $zipPath"
    Write-Host "SHA-256: $($zipHash.Hash)"
    Write-Host "Suma:   $outerChecksumPath"
} finally {
    $env:PATH = $originalPath
    $env:BUILD_NUMBER = $originalBuildNumber
    $env:SIGNTOOL_PATH = $originalSignToolPath
    $env:ELECTRON_BUILDER_SIGN_CERT = $originalSignCertificate
    $env:ELECTRON_BUILDER_SIGN_CERT_PW = $originalSignCertificatePassword

    if ($null -ne $certificate) {
        Remove-Item -LiteralPath "Cert:\CurrentUser\My\$($certificate.Thumbprint)" -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}
