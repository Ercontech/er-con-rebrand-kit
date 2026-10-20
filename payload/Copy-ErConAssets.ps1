# Copies the current Er-Con rebrand assets into the signed-in user's Documents.
# User logon script. If SYSVOL cannot be read, the existing folder is left alone.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$LogDir = Join-Path $env:LOCALAPPDATA 'Er-Con'
$Log = Join-Path $LogDir 'rebrand-assets.log'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log([string]$Message) {
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $Log -Value $line -Encoding UTF8
}

try {
    $src = Join-Path $PSScriptRoot 'Assets'
    $docs = Join-Path $env:USERPROFILE 'Documents'
    $dst = Join-Path $docs 'Er-Con Rebrand Assets'
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Log "Source not reachable ($src). Local folder not changed."
        exit 0
    }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    # /MIR keeps Documents\Er-Con Rebrand Assets equal to the current kit.
    # Fonts to install stays on SYSVOL for the machine install and is not copied here.
    & robocopy.exe $src $dst /MIR /XD "Fonts to install" /R:2 /W:2 /NFL /NDL /NP /XJ
    $code = $LASTEXITCODE
    if ($code -ge 8) {
        Write-Log "robocopy failed with $code"
        exit 1
    }
    Write-Log "Mirrored assets to $dst (robocopy $code)"
    exit 0
}
catch {
    Write-Log ("ERROR " + $_.Exception.Message)
    exit 1
}
