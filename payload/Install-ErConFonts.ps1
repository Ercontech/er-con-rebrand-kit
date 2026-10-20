# Installs the twelve Er-Con static fonts for every user of this PC.
# Computer startup script. Runs as SYSTEM. Does not remove Arial or any other font.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$LogDir = Join-Path $env:ProgramData 'Er-Con'
$Log = Join-Path $LogDir 'rebrand-fonts.log'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log([string]$Message) {
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $Log -Value $line -Encoding UTF8
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

try {
    Write-Log 'Install-ErConFonts start'
    $manifestPath = Join-Path $PSScriptRoot 'fonts.manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-Log "Source not reachable or manifest missing ($manifestPath). Leaving fonts as they are."
        exit 0
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $destDir = Join-Path $env:WINDIR 'Fonts'
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

    if (-not ('ErCon.NativeFont' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace ErCon {
  public static class NativeFont {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int AddFontResource(string lpFileName);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    public static readonly IntPtr HWND_BROADCAST = new IntPtr(0xffff);
    public const uint WM_FONTCHANGE = 0x001D;
  }
}
'@
    }

    $expected = @($manifest.fonts)
    $installed = 0
    foreach ($font in $expected) {
        $rel = ([string]$font.relativePath) -replace '/', '\'
        $src = Join-Path $PSScriptRoot $rel
        if (-not (Test-Path -LiteralPath $src)) {
            Write-Log "MISSING $($font.file)"
            continue
        }
        $hash = Get-Sha256 $src
        $want = ([string]$font.sha256).ToLowerInvariant()
        if ($hash -ne $want) {
            Write-Log "HASH MISMATCH $($font.file) got $hash expected $want"
            continue
        }
        $dest = Join-Path $destDir ([string]$font.file)
        $needCopy = $true
        if (Test-Path -LiteralPath $dest) {
            if ((Get-Sha256 $dest) -eq $hash) { $needCopy = $false }
        }
        if ($needCopy) {
            Copy-Item -LiteralPath $src -Destination $dest -Force
            Write-Log "Copied $($font.file)"
        }
        $valueName = "$($font.fullName) (TrueType)"
        $reg = Get-ItemProperty -Path $regPath
        $current = $reg.PSObject.Properties[$valueName].Value
        if ($current -ne $font.file) {
            New-ItemProperty -Path $regPath -Name $valueName -Value ([string]$font.file) -PropertyType String -Force | Out-Null
            Write-Log "Registered $valueName"
        }
        $added = [ErCon.NativeFont]::AddFontResource($dest)
        Write-Log "AddFontResource $($font.file) -> $added"
        $installed++
    }

    $fontRoot = Join-Path $PSScriptRoot 'Assets\Fonts to install'
    if (Test-Path -LiteralPath $fontRoot) {
        $allowed = @{}
        foreach ($font in $expected) { $allowed[[string]$font.file] = $true }
        Get-ChildItem -LiteralPath $fontRoot -Recurse -File -Include *.ttf, *.otf, *.ttc | ForEach-Object {
            if (-not $allowed.ContainsKey($_.Name)) {
                Write-Log "SKIPPED extra font file (not one of the twelve): $($_.Name)"
            }
        }
    }

    [void][ErCon.NativeFont]::SendMessage(
        [ErCon.NativeFont]::HWND_BROADCAST,
        [ErCon.NativeFont]::WM_FONTCHANGE,
        [IntPtr]::Zero,
        [IntPtr]::Zero)

    $reg = Get-ItemProperty -Path $regPath
    $arial = $reg.PSObject.Properties['Arial (TrueType)'].Value
    if ($arial) {
        Write-Log "Arial still registered ($arial). Not modified."
    }
    else {
        Write-Log 'WARNING: Arial (TrueType) is not registered. This package does not remove fonts.'
    }

    @{
        kit       = [string]$manifest.version
        installed = $installed
        expected  = $expected.Count
        at        = (Get-Date).ToString('o')
        computer  = $env:COMPUTERNAME
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $LogDir 'fonts-installed.json') -Encoding UTF8

    Write-Log "Install-ErConFonts done ($installed of $($expected.Count))"
    if ($installed -lt $expected.Count) { exit 1 }
    exit 0
}
catch {
    Write-Log ("ERROR " + $_.Exception.Message)
    exit 1
}
