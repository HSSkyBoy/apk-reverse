#requires -Version 5

[CmdletBinding()]
param(
    [switch]$CheckOnly,

    [switch]$SkipRefresh
)

<#
.SYNOPSIS
Deterministic server management for the apk-reverse MCP analysis service.

.DESCRIPTION
Checks prerequisites (jadx, apktool, frida, adb), bootstraps missing tools
when allowed, and reports environment status via key=value output.
Use this script for consistent service startup — do NOT write ad-hoc
PowerShell commands for these operations.

.PARAMETER CheckOnly
Report status without attempting any installation.

.PARAMETER SkipRefresh
Passed through to bootstrap scripts; skips refresh after install.

.OUTPUTS
key=value lines to stdout:
  status=ready|degraded|unavailable
  jadx=available|missing
  apktool=available|missing
  frida=available|missing
  adb=available|missing
  python=available|missing
  java=available|missing
  zipalign=available|missing
  apksigner=available|missing
  keytool=available|missing
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib\Encoding.ps1')
. (Join-Path $PSScriptRoot 'lib\ToolDiscovery.ps1')

function Test-ToolAvailable {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $true }

    if ($Name -in @('jadx', 'apktool')) {
        $spec = Resolve-ReverseToolSpec -Name $Name
        return $spec.Available
    }

    if ($Name -eq 'frida') {
        $fridaCmd = Get-Command frida -ErrorAction SilentlyContinue
        if ($fridaCmd) { return $true }
        # Check pip install paths
        $pythonRoots = @(
            (Join-Path $env:APPDATA 'Python'),
            (Join-Path $env:LOCALAPPDATA 'Programs\Python')
        )
        foreach ($root in $pythonRoots) {
            if (-not (Test-Path -LiteralPath $root)) { continue }
            $dirs = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue
            foreach ($dir in $dirs) {
                if (Test-Path -LiteralPath (Join-Path $dir.FullName 'Scripts\frida.exe')) {
                    return $true
                }
            }
        }
        return $false
    }

    if ($Name -eq 'adb') {
        $sdkAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
        if (Test-Path -LiteralPath $sdkAdb) { return $true }
        return $false
    }

    if ($Name -in @('zipalign', 'apksigner')) {
        $sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
        if (Test-Path -LiteralPath (Join-Path $sdkRoot 'build-tools')) {
            $buildTools = Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Directory -ErrorAction SilentlyContinue |
                Sort-Object -Property Name -Descending
            foreach ($bt in $buildTools) {
                if (Test-Path -LiteralPath (Join-Path $bt.FullName "$Name.exe")) {
                    return $true
                }
                if (Test-Path -LiteralPath (Join-Path $bt.FullName "$Name.bat")) {
                    return $true
                }
            }
        }
        return $false
    }

    if ($Name -eq 'keytool') {
        try {
            $null = & keytool -help 2>$null
            return $true
        } catch {
            return $false
        }
    }

    return $false
}

# Tool inventory
$tools = @{}
$bootstrapTargets = @()

foreach ($tool in @('jadx', 'apktool', 'frida', 'adb', 'python', 'java', 'zipalign', 'apksigner', 'keytool')) {
    $available = Test-ToolAvailable -Name $tool
    $tools[$tool] = $available
}

# Auto-bootstrap missing tools unless --CheckOnly
if (-not $CheckOnly) {
    $bootstrapScript = Join-Path $PSScriptRoot 'bootstrap-reverse.ps1'
    $autoBootstrap = @('jadx', 'apktool', 'frida', 'adb')

    foreach ($tool in $autoBootstrap) {
        if (-not $tools[$tool]) {
            Write-Host "INFO: $tool not found, attempting auto-bootstrap..." -ForegroundColor Yellow
            $bsArgs = @('-File', $bootstrapScript, '-Capability', @($tool))
            if ($SkipRefresh) { $bsArgs += '-SkipRefresh' }
            & powershell.exe -NoProfile -ExecutionPolicy Bypass @bsArgs
            if ($LASTEXITCODE -eq 0) {
                $tools[$tool] = Test-ToolAvailable -Name $tool
            }
        }
    }
}

# Compute overall status
$criticalTools = @('jadx', 'apktool', 'frida', 'adb')
$allReady = ($criticalTools | Where-Object { -not $tools[$_] }).Count -eq 0
$anyReady = ($criticalTools | Where-Object { $tools[$_] }).Count -gt 0

if ($allReady) {
    $status = 'ready'
} elseif ($anyReady) {
    $status = 'degraded'
} else {
    $status = 'unavailable'
}

"status=$status"
foreach ($tool in $tools.Keys | Sort-Object) {
    "$tool=$($tools[$tool] ? 'available' : 'missing')"
}
