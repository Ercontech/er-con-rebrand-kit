# Disables the Er-Con rebrand GPO link. Does not uninstall fonts already on PCs.
#Requires -Version 5.1
#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory, GroupPolicy
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('er-contech')]
    [string]$ConfirmDomainWide,

    [string]$TargetDn,

    [switch]$DeleteGpo,

    [switch]$DeleteSysvolPayload
)

$ErrorActionPreference = 'Stop'
$GpoName = 'Er-Con Rebrand - Fonts and Assets'
$domain = Get-ADDomain
$dns = $domain.DNSRoot
$nb = $domain.NetBIOSName
$dnsOk = ($dns -eq 'er-contech') -or $dns.StartsWith('er-contech.')
if (-not ($dnsOk -or ($nb -eq 'ER-CONTECH'))) {
    throw "Refusing to change policy. This machine is DNS '$dns', NetBIOS '$nb'."
}
if (-not $TargetDn) { $TargetDn = $domain.DistinguishedName }

$exists = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
if (-not $exists) {
    Write-Output "No GPO named '$GpoName' in $dns."
}
else {
    $inheritance = Get-GPInheritance -Target $TargetDn
    $link = @($inheritance.GpoLinks | Where-Object { $_.DisplayName -eq $GpoName })
    if ($link.Count -gt 0) {
        if ($DeleteGpo) {
            Remove-GPLink -Name $GpoName -Target $TargetDn
            Write-Output "Removed the link from $TargetDn."
        }
        else {
            Set-GPLink -Name $GpoName -Target $TargetDn -LinkEnabled No -Enforced No
            Write-Output "Disabled the link on $TargetDn. The GPO still exists."
        }
    }
    if ($DeleteGpo) {
        Remove-GPO -Name $GpoName
        Write-Output "Deleted the GPO."
    }
}

if ($DeleteSysvolPayload) {
    $sysvol = "\\$dns\SYSVOL\$dns\ErCon-Rebrand"
    if (Test-Path -LiteralPath $sysvol) {
        Remove-Item -LiteralPath $sysvol -Recurse -Force
        Write-Output "Removed $sysvol."
    }
}

Write-Output ""
Write-Output "Fonts already installed on PCs are still installed. Arial was never removed."
Write-Output "To uninstall the twelve faces from one PC, run payload\Remove-ErConFonts.ps1 as admin on that PC."
Write-Output "That script deletes a font file only when its hash still matches this kit."
