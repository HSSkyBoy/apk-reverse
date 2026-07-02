#requires -Version 5

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Capability,

    [switch]$SkipRefresh
)

<#
.SYNOPSIS
Interactive tool bootstrap for APK reverse engineering tools.

.DESCRIPTION
Checks for the presence of jadx, apktool, frida, and adb.
If tools are missing, asks the user before downloading/installing them.
Supports: jadx, apktool, frida, adb

.PARAMETER Capability
List of tool capabilities to ensure. Valid: jadx, apktool, frida, adb

.PARAMETER SkipRefresh
Skip refreshing after install (passed through from calling scripts).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-ToolAvailable {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $true }

    $toolDir = Join-Path $env:USERPROFILE "Tools\$Name"
    if (Test-Path -LiteralPath $toolDir) {
        if ((Get-ChildItem -LiteralPath $toolDir -Filter "$Name.*" -ErrorAction SilentlyContinue).Count -gt 0) {
            return $true
        }
    }

    # Check SDK paths for adb
    if ($Name -eq 'adb') {
        $sdkAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
        if (Test-Path -LiteralPath $sdkAdb) { return $true }
    }

    return $false
}

function Install-Jadx {
    Write-Host "INFO: jadx installation requires manual download." -ForegroundColor Yellow
    Write-Host "  Download from: https://github.com/skylot/jadx/releases/latest"
    Write-Host "  Extract to: $env:USERPROFILE\Tools\jadx\"
    Write-Host "  Or install via: winget install jadx"
}

function Install-Apktool {
    Write-Host "INFO: apktool installation requires manual download." -ForegroundColor Yellow
    Write-Host "  Download apktool_2.x.x.jar from: https://apktool.org/"
    Write-Host "  Place in: $env:USERPROFILE\Tools\apktool\"
    Write-Host "  Create wrapper script apktool.bat: @java -jar %~dp0apktool_2.x.x.jar %*"
}

function Install-Frida {
    Write-Host "INFO: Installing frida-tools via pip..." -ForegroundColor Yellow
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        Write-Host "ERR: Python not found. Please install Python first, then run: pip install frida-tools"
        return
    }
    & $python.Source -m pip install frida-tools
    if ($LASTEXITCODE -eq 0) {
        Write-Host "INFO: frida-tools installed successfully." -ForegroundColor Green
    } else {
        Write-Host "WARNING: pip install returned exit code $LASTEXITCODE."
    }
}

function Install-Adb {
    Write-Host "INFO: Attempting adb install via winget..." -ForegroundColor Yellow
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        & winget install Google.PlatformTools --silent
        if ($LASTEXITCODE -eq 0) {
            Write-Host "INFO: Android Platform-Tools installed via winget." -ForegroundColor Green
            return
        }
    }
    Write-Host "INFO: adb installation requires manual setup." -ForegroundColor Yellow
    Write-Host "  Download from: https://developer.android.com/studio/releases/platform-tools"
    Write-Host "  Or install via Android SDK Manager: sdkmanager 'platform-tools'"
}

# Main: check each capability
$missing = @()
foreach ($cap in $Capability) {
    if (-not (Test-ToolAvailable -Name $cap)) {
        $missing += $cap
    }
}

if ($missing.Count -eq 0) {
    Write-Host "INFO: All requested tools are already available." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Missing Tools Detected" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

foreach ($m in $missing) {
    Write-Host "  [?] $m is not installed" -ForegroundColor Yellow
}

Write-Host ""
$response = Read-Host "Do you want to attempt automatic installation? (y/n)"

if ($response -notin @('y', 'Y', 'yes', 'Yes')) {
    Write-Host "INFO: Skipping automatic installation. Please install tools manually." -ForegroundColor Yellow
    Write-Host "  Missing: $($missing -join ', ')"
    exit 1
}

foreach ($m in $missing) {
    Write-Host ""
    Write-Host "--- Installing $m ---" -ForegroundColor Cyan
    switch ($m) {
        'jadx'    { Install-Jadx }
        'apktool' { Install-Apktool }
        'frida'   { Install-Frida }
        'adb'     { Install-Adb }
    }
}

Write-Host ""
Write-Host "INFO: Bootstrap complete. Re-run your command to use the newly installed tools." -ForegroundColor Green
