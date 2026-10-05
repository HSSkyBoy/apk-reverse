# ToolDiscovery.ps1 — Resolve tool paths for jadx, apktool, and future tools.
# Dot-sourced by decode.ps1 and other scripts that need tool resolution.

function Resolve-ReverseToolSpec {
    param([Parameter(Mandatory = $true)][string]$Name)

    # Check PATH first
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        return [PSCustomObject]@{
            Available  = $true
            Command    = $cmd.Source
            PrefixArgs = @()
        }
    }

    # Fallback: well-known install roots (REVERSE_TOOLS_DIR, %USERPROFILE%\Tools, E:\Tools)
    foreach ($root in Get-ReverseToolRoots) {
        $found = Find-ReverseToolInRoot -Root $root -Name $Name
        if ($found) { return $found }
    }

    # Not found
    return [PSCustomObject]@{
        Available  = $false
        Command    = ''
        PrefixArgs = @()
    }
}

# Also expose a simple PATH-only lookup for scripts that don't need the full spec
function Find-ToolOnPath {
    param([Parameter(Mandatory = $true)][string]$Name)

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

# Install roots searched when a tool is not on PATH. Override with REVERSE_TOOLS_DIR.
function Get-ReverseToolRoots {
    $roots = @()
    if ($env:REVERSE_TOOLS_DIR) { $roots += $env:REVERSE_TOOLS_DIR }
    if ($env:USERPROFILE) { $roots += (Join-Path $env:USERPROFILE 'Tools') }
    $roots += 'E:\Tools'
    $roots | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Unique
}

# Looks for <Name>.bat/.cmd/.exe or <Name>*.jar in the root itself, in <Name>*\ and <Name>*\bin\
# (handles versioned folders such as jadx-1.5.6\bin\jadx.bat and apktool_3.0.2.jar next to apktool.bat).
function Find-ReverseToolInRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $dirs = @($Root)
    $dirs += Get-ChildItem -LiteralPath $Root -Directory -Filter "$Name*" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | ForEach-Object { $_.FullName }

    foreach ($dir in $dirs) {
        foreach ($base in @($dir, (Join-Path $dir 'bin'))) {
            if (-not (Test-Path -LiteralPath $base)) { continue }
            foreach ($ext in @('bat', 'cmd', 'exe')) {
                $candidate = Join-Path $base "$Name.$ext"
                if (Test-Path -LiteralPath $candidate) {
                    return [PSCustomObject]@{ Available = $true; Command = $candidate; PrefixArgs = @() }
                }
            }
            $jar = Get-ChildItem -LiteralPath $base -Filter "$Name*.jar" -File -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1
            if ($jar) {
                return [PSCustomObject]@{ Available = $true; Command = 'java'; PrefixArgs = @('-jar', $jar.FullName) }
            }
        }
    }
    return $null
}
