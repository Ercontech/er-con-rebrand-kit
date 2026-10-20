# Creates D:\Er-Con Rebrand Assets, shares it, and sets NTFS and share permissions.
# Run elevated on the server whose D: drive should hold the share.
#Requires -Version 5.1
#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('er-contech')]
    [string]$ConfirmDomainWide,

    [Parameter(Mandatory = $true)]
    [string]$SourceAssets
)

$ErrorActionPreference = 'Stop'
$Folder = 'D:\Er-Con Rebrand Assets'
$ShareName = 'Er-Con Rebrand Assets'

function Convert-SidToAccount([string]$Sid) {
    return (New-Object System.Security.Principal.SecurityIdentifier($Sid)).Translate(
        [System.Security.Principal.NTAccount]).Value
}

$domain = Get-ADDomain
$dns = $domain.DNSRoot
$nb = $domain.NetBIOSName
$dnsOk = ($dns -eq 'er-contech') -or $dns.StartsWith('er-contech.')
if (-not ($dnsOk -or ($nb -eq 'ER-CONTECH'))) {
    throw "Refusing to create the share. This machine is DNS '$dns', NetBIOS '$nb'."
}
if (-not (Test-Path -LiteralPath 'D:\')) {
    throw "D:\ is not on this server. Run this script on the server whose D: drive should hold Er-Con Rebrand Assets, then run Deploy-ErConRebrandGpo.ps1 -SkipAssetShare on the domain controller."
}
if (-not (Test-Path -LiteralPath $SourceAssets)) {
    throw "Asset source not found: $SourceAssets"
}

Write-Output "Creating $Folder"
New-Item -ItemType Directory -Force -Path $Folder | Out-Null
& robocopy.exe $SourceAssets $Folder /MIR /XD "Fonts to install" /R:2 /W:2 /NFL /NDL /NP
if ($LASTEXITCODE -ge 8) {
    throw "robocopy could not fill $Folder (exit $LASTEXITCODE)."
}
$fontsInShare = Join-Path $Folder 'Fonts to install'
if (Test-Path -LiteralPath $fontsInShare) {
    Remove-Item -LiteralPath $fontsInShare -Recurse -Force
}

$admins = Convert-SidToAccount 'S-1-5-32-544'
$system = Convert-SidToAccount 'S-1-5-18'
$users = Convert-SidToAccount 'S-1-5-11'
$domainAdminsSid = (Get-ADGroup -Identity 'Domain Admins').SID
$domainAdmins = $domainAdminsSid.Translate([System.Security.Principal.NTAccount]).Value

Write-Output "Setting NTFS permissions. Users can read. Only administrators can change files."
& icacls.exe $Folder /inheritance:r | Out-Null
if ($LASTEXITCODE -ne 0) { throw "icacls could not stop inheritance on $Folder (exit $LASTEXITCODE)." }
& icacls.exe $Folder /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" "*$($domainAdminsSid.Value):(OI)(CI)F" "*S-1-5-11:(OI)(CI)RX" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "icacls could not set permissions on $Folder (exit $LASTEXITCODE)." }

$existing = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
if ($existing) {
    if ($existing.Path -ne $Folder) {
        throw "A share named '$ShareName' already points at '$($existing.Path)', not '$Folder'. Rename that share or remove it, then run this again."
    }
    Write-Output "Share already exists. Replacing its access list."
}
else {
    New-SmbShare -Name $ShareName -Path $Folder -Description 'Er-Con rebrand assets. Read-only for staff.' -CachingMode None | Out-Null
}

$names = @(Get-SmbShareAccess -Name $ShareName | Select-Object -ExpandProperty AccountName)
foreach ($name in $names) {
    Revoke-SmbShareAccess -Name $ShareName -AccountName $name -Force | Out-Null
}
Grant-SmbShareAccess -Name $ShareName -AccountName $admins -AccessRight Full -Force | Out-Null
Grant-SmbShareAccess -Name $ShareName -AccountName $domainAdmins -AccessRight Full -Force | Out-Null
Grant-SmbShareAccess -Name $ShareName -AccountName $users -AccessRight Read -Force | Out-Null
Set-SmbShare -Name $ShareName -CachingMode None -Force | Out-Null

$unc = "\\$env:COMPUTERNAME\$ShareName"
Write-Output ""
Write-Output "Folder:  $Folder"
Write-Output "Share:   $unc"
Write-Output "NTFS:    $system Full, $admins Full, $domainAdmins Full, $users Read"
Write-Output "Share:   $admins Full, $domainAdmins Full, $users Read"
Write-Output "Staff can open the share. They cannot add, change, or delete files there."
