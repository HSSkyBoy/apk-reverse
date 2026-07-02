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

    # Fallback: check %USERPROFILE%\Tools\ for common tool installs
    $toolDir = Join-Path $env:USERPROFILE "Tools\$Name"
    if (Test-Path -LiteralPath $toolDir) {
        $bat = Join-Path $toolDir "$Name.bat"
        $exe = Join-Path $toolDir "$Name.exe"
        $jar = Join-Path $toolDir "$Name.jar"

        if (Test-Path -LiteralPath $bat) {
            return [PSCustomObject]@{
                Available  = $true
                Command    = $bat
                PrefixArgs = @()
            }
        }
        if (Test-Path -LiteralPath $exe) {
            # jadx installs a lib/ directory alongside the exe
            if ($Name -eq 'jadx') {
                return [PSCustomObject]@{
                    Available  = $true
                    Command    = $exe
                    PrefixArgs = @()
                }
            }
            return [PSCustomObject]@{
                Available  = $true
                Command    = $exe
                PrefixArgs = @()
            }
        }
        # Wrap .jar with java
        if (Test-Path -LiteralPath $jar) {
            return [PSCustomObject]@{
                Available  = $true
                Command    = 'java'
                PrefixArgs = @('-jar', $jar)
            }
        }

        # Check for standalone jar files (e.g., apktool_2.x.x.jar)
        $jars = Get-ChildItem -LiteralPath $toolDir -Filter '*.jar' -ErrorAction SilentlyContinue
        if ($jars -and $jars.Count -gt 0) {
            return [PSCustomObject]@{
                Available  = $true
                Command    = 'java'
                PrefixArgs = @('-jar', $jars[0].FullName)
            }
        }
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
