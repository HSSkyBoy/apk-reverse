#requires -Version 5

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [string]$Name,

    [string]$OutRoot,

    [switch]$DetectOnly,

    [switch]$Decode,

    [switch]$Clean
)

<#
.SYNOPSIS
Deterministic file opening for the apk-reverse MCP analysis service.

.DESCRIPTION
Accepts a target file path, detects file type (APK, ELF, PE, Mach-O, etc.),
and routes to the appropriate analysis pipeline. For APK targets, delegates
to decode.ps1 for full jadx + apktool processing.
Use this script for consistent file loading — do NOT write ad-hoc
PowerShell commands for these operations.

.PARAMETER TargetPath
Path to the target file (APK, SO, ELF, PE, etc.).

.PARAMETER Name
Optional task name override (passed through to decode.ps1).

.PARAMETER OutRoot
Optional output directory override (passed through to decode.ps1).

.PARAMETER DetectOnly
Only detect and report file type — skip any processing.

.PARAMETER Decode
For APK targets, automatically run full decode pipeline (jadx + apktool).

.PARAMETER Clean
Remove existing output directory before decoding.

.OUTPUTS
key=value lines to stdout:
  type=apk|elf|pe|macho|other
  path=<resolved absolute path>
  mime=<detected MIME type>
  size=<file size in bytes>
  decode_target=apk|so|none (routing hint)
  For APK + --Decode: additionally produces all decode.ps1 output keys.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib\Encoding.ps1')

function Get-FileType {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Target file not found: $Path"
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 4) {
        return 'other'
    }

    # ZIP magic (APK is a ZIP)
    if ($bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B) {
        return 'apk'
    }

    # ELF magic
    if ($bytes[0] -eq 0x7F -and $bytes[1] -eq 0x45 -and $bytes[2] -eq 0x4C -and $bytes[3] -eq 0x46) {
        return 'elf'
    }

    # PE magic (MZ)
    if ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) {
        return 'pe'
    }

    # Mach-O magic (32-bit: FEEDFACE, 64-bit: FEEDFACF; also FAT: CAFEBABE / BEBAFECA)
    if ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xED -and $bytes[2] -eq 0xFA) {
        return 'macho'
    }
    if ($bytes[0] -eq 0xCF -and $bytes[1] -eq 0xFA -and $bytes[2] -eq 0xED -and $bytes[3] -eq 0xFE) {
        return 'macho'
    }
    if ($bytes[0] -eq 0xCA -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0xBA -and $bytes[3] -eq 0xBE) {
        return 'macho'
    }
    if ($bytes[0] -eq 0xBE -and $bytes[1] -eq 0xBA -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xCA) {
        return 'macho'
    }

    return 'other'
}

function Get-MimeFromType {
    param([Parameter(Mandatory = $true)][string]$Type)

    switch ($Type) {
        'apk'   { return 'application/vnd.android.package-archive' }
        'elf'   { return 'application/x-elf' }
        'pe'    { return 'application/x-dosexec' }
        'macho' { return 'application/x-mach-o' }
        default { return 'application/octet-stream' }
    }
}

function Get-DecodeTarget {
    param([Parameter(Mandatory = $true)][string]$Type)

    switch ($Type) {
        'apk' { return 'apk' }
        'elf' { return 'so' }
        'pe'  { return 'so' }
        'macho' { return 'so' }
        default { return 'none' }
    }
}

# Resolve path
$resolvedPath = [System.IO.Path]::GetFullPath($TargetPath)

# Detect type
$fileType = Get-FileType -Path $resolvedPath
$mime = Get-MimeFromType -Type $fileType
$fileInfo = Get-Item -LiteralPath $resolvedPath
$sizeBytes = $fileInfo.Length
$decodeTarget = Get-DecodeTarget -Type $fileType

"type=$fileType"
"path=$resolvedPath"
"mime=$mime"
"size=$sizeBytes"
"decode_target=$decodeTarget"

if ($DetectOnly) {
    exit 0
}

# Route to decode pipeline for APK
if ($Decode -and $fileType -eq 'apk') {
    $decodeScript = Join-Path $PSScriptRoot 'decode.ps1'
    if (-not (Test-Path -LiteralPath $decodeScript)) {
        throw "Decode script not found: $decodeScript"
    }

    $decodeArgs = @(
        '-File', $decodeScript,
        '-ApkPath', $resolvedPath
    )
    if ($Name) {
        $decodeArgs += '-Name'
        $decodeArgs += $Name
    }
    if ($OutRoot) {
        $decodeArgs += '-OutRoot'
        $decodeArgs += $OutRoot
    }
    if ($Clean) {
        $decodeArgs += '-Clean'
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass @decodeArgs
    exit $LASTEXITCODE
}

# For non-APK targets with --Decode, report routing
if ($Decode -and $fileType -ne 'apk') {
    Write-Host "INFO: --Decode only applies to APK targets. Use Part 2 / Part 3 reference materials for $fileType analysis." -ForegroundColor Yellow
    "routing_hint=refer_to_part_2_or_3_for_$fileType"
}
