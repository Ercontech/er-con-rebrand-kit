# Removes only the twelve Er-Con fonts this kit installed, and only when the
# file on disk still matches the kit hash. Never touches Arial or any other family.
#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$RemoveProfileCopy
)
$ErrorActionPreference = 'Stop'

$manifestPath = Join-Path $PSScriptRoot 'fonts.manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "fonts.manifest.json was not found next to this script."
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$destDir = Join-Path $env:WINDIR 'Fonts'
$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

if (-not ('ErCon.NativeFontRemove' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
namespace ErCon {
  public static class NativeFontRemove {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    public static extern bool RemoveFontResource(string lpFileName);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern System.IntPtr SendMessage(System.IntPtr hWnd, uint Msg, System.IntPtr wParam, System.IntPtr lParam);
    public static readonly System.IntPtr HWND_BROADCAST = new System.IntPtr(0xffff);
    public const uint WM_FONTCHANGE = 0x001D;
  }
}
'@
}

foreach ($font in @($manifest.fonts)) {
    if ($font.file -like 'arial*') { throw "Refusing to remove $($font.file)." }
    $valueName = "$($font.fullName) (TrueType)"
    $reg = Get-ItemProperty -Path $regPath
    $current = $reg.PSObject.Properties[$valueName].Value
    if ($current -eq $font.file) {
        Remove-ItemProperty -Path $regPath -Name $valueName
        Write-Output "Unregistered $valueName"
    }
    $dest = Join-Path $destDir ([string]$font.file)
    if (Test-Path -LiteralPath $dest) {
        $hash = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -eq ([string]$font.sha256).ToLowerInvariant()) {
            [void][ErCon.NativeFontRemove]::RemoveFontResource($dest)
            Remove-Item -LiteralPath $dest -Force
            Write-Output "Removed $($font.file)"
        }
        else {
            Write-Output "LEFT $($font.file) in place because its hash does not match this kit."
        }
    }
}

[void][ErCon.NativeFontRemove]::SendMessage(
    [ErCon.NativeFontRemove]::HWND_BROADCAST,
    [ErCon.NativeFontRemove]::WM_FONTCHANGE,
    [IntPtr]::Zero,
    [IntPtr]::Zero)

if ($RemoveProfileCopy) {
    $home = Join-Path (Join-Path $env:USERPROFILE 'Documents') 'Er-Con Rebrand Assets'
    if (Test-Path -LiteralPath $home) {
        Remove-Item -LiteralPath $home -Recurse -Force
        Write-Output "Removed $home"
    }
}
else {
    Write-Output "Documents folder left in place. Pass -RemoveProfileCopy to delete the current user's copy only."
}
