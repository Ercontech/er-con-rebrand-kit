# Links "Er-Con Rebrand - Fonts and Assets" in the er-contech domain.
# Run from this folder, on a domain controller or a PC with RSAT, as a Domain Admin.
#Requires -Version 5.1
#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory, GroupPolicy
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('er-contech')]
    [string]$ConfirmDomainWide,

    [string]$ExpectedDnsName,

    [string]$TargetDn,

    [switch]$WorkstationsOnly,

    [bool]$Enforce = $true,

    [switch]$SkipAssetShare
)

$ErrorActionPreference = 'Stop'
$GpoName = 'Er-Con Rebrand - Fonts and Assets'
$ScriptCse = '[{42B5FA4E-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}]'

function Write-Step([string]$Message) {
    Write-Output ""
    Write-Output "== $Message"
}

function Write-Utf8Bom([string]$Path, [string]$Content) {
    $enc = New-Object System.Text.UTF8Encoding $true
    $text = ($Content -replace "`r`n", "`n" -replace "`n", "`r`n")
    [System.IO.File]::WriteAllText($Path, $text, $enc)
}

function Write-UnicodeIni([string]$Path, [string]$Content) {
    $enc = New-Object System.Text.UnicodeEncoding $false, $true
    $text = ($Content.Trim() -replace "`r`n", "`n" -replace "`n", "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($Path, $text, $enc)
}

function Assert-ErConDomain {
    $domain = Get-ADDomain
    $dns = $domain.DNSRoot
    $nb = $domain.NetBIOSName
    $dnsOk = ($dns -eq 'er-contech') -or $dns.StartsWith('er-contech.')
    $nbOk = ($nb -eq 'ER-CONTECH')
    if (-not ($dnsOk -or $nbOk)) {
        throw "Refusing to deploy. This kit is only for the er-contech domain. This machine is DNS '$dns', NetBIOS '$nb'."
    }
    if ($ExpectedDnsName -and ($dns -ne $ExpectedDnsName)) {
        throw "This domain controller is in '$dns', not '$ExpectedDnsName'. Re-run with the DNS name this DC printed, or omit -ExpectedDnsName."
    }
    return $domain
}

Write-Step 'Checking this is the er-contech domain'
$domain = Assert-ErConDomain
$dns = $domain.DNSRoot
if (-not $TargetDn) { $TargetDn = $domain.DistinguishedName }
if ($TargetDn -notmatch '(?i)DC=') {
    throw "-TargetDn must be a distinguished name. Got '$TargetDn'."
}

Write-Output "Domain:     $dns ($($domain.NetBIOSName))"
Write-Output "Link:       $TargetDn"
Write-Output "Enforced:   $Enforce"
Write-Output "Scope:      $(if ($WorkstationsOnly) { 'Windows workstations only (WMI ProductType = 1)' } else { 'Every Windows computer that applies Group Policy, including servers and domain controllers' })"
Write-Output "GPO:        $GpoName"
Write-Output "Arial:      left installed. This script never deletes a font."
Write-Output "Share:      $(if ($SkipAssetShare) { 'Skipped. -SkipAssetShare was set.' } else { 'D:\Er-Con Rebrand Assets, shared read-only to Authenticated Users' })"

$payload = Join-Path $PSScriptRoot 'payload'
$manifest = Join-Path $payload 'fonts.manifest.json'
if (-not (Test-Path -LiteralPath $manifest)) {
    $here = (Get-Location).Path
    throw @"
payload\fonts.manifest.json is missing.

You must run this script from the folder that contains Deploy-ErConRebrandGpo.ps1
and the payload\ directory (the kit root, often named ErCon-Rebrand-GPO).

  Current directory:  $here
  Script location:    $PSScriptRoot

Typical fix:
  cd C:\Path\Where\You\Unzipped\ErCon-Rebrand-GPO
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Deploy-ErConRebrandGpo.ps1 -ConfirmDomainWide er-contech -TargetDn `"OU=Pilot,DC=er-contech,DC=local`"

Do not run the command from C:\Windows\system32 or any other folder that does not contain the script.
"@
}

Write-Step "Copying the kit to \\$dns\SYSVOL\$dns\ErCon-Rebrand"
$sysvol = "\\$dns\SYSVOL\$dns\ErCon-Rebrand"
New-Item -ItemType Directory -Force -Path $sysvol | Out-Null
& robocopy.exe $payload $sysvol /MIR /R:2 /W:2 /NFL /NDL /NP
if ($LASTEXITCODE -ge 8) {
    throw "robocopy could not write $sysvol (exit $LASTEXITCODE)."
}

Write-Step 'Creating the GPO'
$gpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
if (-not $gpo) {
    $gpo = New-GPO -Name $GpoName -Comment 'Er-Con rebrand, October 2026. Installs Archivo, Source Sans 3 and IBM Plex Mono, and copies Er-Con Rebrand Assets into each user Documents folder. Does not remove Arial.'
}
try { $gpo.Description = 'Er-Con rebrand, October 2026. Static fonts plus the asset folder. Arial is not removed.' } catch { }

$guid = $gpo.Id.ToString()
$policyPath = "\\$dns\SYSVOL\$dns\Policies\{$guid}"
if (-not (Test-Path -LiteralPath $policyPath)) {
    throw "GPO folder not found at $policyPath. Check SYSVOL replication and run this again."
}

Write-Step 'Writing startup and logon scripts'
$machineStartup = Join-Path $policyPath 'Machine\Scripts\Startup'
$userLogon = Join-Path $policyPath 'User\Scripts\Logon'
New-Item -ItemType Directory -Force -Path $machineStartup, $userLogon | Out-Null

$launchInstall = @'
$ErrorActionPreference = 'Stop'
$system = Get-CimInstance -ClassName Win32_ComputerSystem
$dnsName = [string]$system.Domain
if ([string]::IsNullOrWhiteSpace($dnsName) -or $dnsName -eq 'WORKGROUP') { exit 0 }
$script = "\\$dnsName\SYSVOL\$dnsName\ErCon-Rebrand\Install-ErConFonts.ps1"
if (-not (Test-Path -LiteralPath $script)) { exit 0 }
& $script
'@
$launchCopy = @'
$ErrorActionPreference = 'Stop'
$system = Get-CimInstance -ClassName Win32_ComputerSystem
$dnsName = [string]$system.Domain
if ([string]::IsNullOrWhiteSpace($dnsName) -or $dnsName -eq 'WORKGROUP') { exit 0 }
$script = "\\$dnsName\SYSVOL\$dnsName\ErCon-Rebrand\Copy-ErConAssets.ps1"
if (-not (Test-Path -LiteralPath $script)) { exit 0 }
& $script
'@
Write-Utf8Bom (Join-Path $machineStartup 'Launch-Install-ErConFonts.ps1') $launchInstall
Write-Utf8Bom (Join-Path $userLogon 'Launch-Copy-ErConAssets.ps1') $launchCopy
Write-UnicodeIni (Join-Path $policyPath 'Machine\Scripts\psscripts.ini') @"
[Startup]
0CmdLine=Launch-Install-ErConFonts.ps1
0Parameters=
"@
Write-UnicodeIni (Join-Path $policyPath 'Machine\Scripts\scripts.ini') @"
[Startup]
"@
Write-UnicodeIni (Join-Path $policyPath 'User\Scripts\psscripts.ini') @"
[Logon]
0CmdLine=Launch-Copy-ErConAssets.ps1
0Parameters=
"@
Write-UnicodeIni (Join-Path $policyPath 'User\Scripts\scripts.ini') @"
[Logon]
"@

Write-Step 'Setting the policies that make the scripts actually run'
# Wait for the network so the startup script can see SYSVOL.
Set-GPRegistryValue -Name $GpoName -Key 'HKLM\Software\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon' -ValueName 'SyncForegroundPolicy' -Type DWord -Value 1 | Out-Null
# Disabled "run startup scripts asynchronously" is DWORD 1: Windows waits for the font install.
Set-GPRegistryValue -Name $GpoName -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System' -ValueName 'RunStartupScriptSync' -Type DWord -Value 1 | Out-Null
# Disabled "Configure Logon Script Delay": the asset folder is copied at logon, not five minutes later.
Set-GPRegistryValue -Name $GpoName -Key 'HKLM\Software\Policies\Microsoft\Windows\System' -ValueName 'EnableLogonScriptDelay' -Type DWord -Value 0 | Out-Null
Set-GPRegistryValue -Name $GpoName -Key 'HKLM\Software\Er-Con\Rebrand' -ValueName 'Kit' -Type String -Value '2026.10.19' | Out-Null
Set-GPRegistryValue -Name $GpoName -Key 'HKLM\Software\Er-Con\Rebrand' -ValueName 'Scope' -Type String -Value 'er-contech' | Out-Null

Write-Step 'Registering the script client-side extension'
$adGpo = Get-ADObject -Identity $gpo.Path -Properties gPCMachineExtensionNames, gPCUserExtensionNames
$machineExt = [string]$adGpo.gPCMachineExtensionNames
$userExt = [string]$adGpo.gPCUserExtensionNames
if ($machineExt -notlike '*{42B5FA4E-6536-11D2-AE5A-0000F87571E3}*') { $machineExt += $ScriptCse }
if ($userExt -notlike '*{42B5FA4E-6536-11D2-AE5A-0000F87571E3}*') { $userExt += $ScriptCse }
Set-ADObject -Identity $gpo.Path -Replace @{
    gPCMachineExtensionNames = $machineExt
    gPCUserExtensionNames    = $userExt
}

if ($WorkstationsOnly) {
    Write-Step 'Attaching the workstation WMI filter'
    $wmiName = 'Er-Con Rebrand - Windows workstations only'
    $wql = 'SELECT * FROM Win32_OperatingSystem WHERE ProductType = 1'
    $somBase = "CN=SOM,CN=WMIPolicy,CN=System,$($domain.DistinguishedName)"
    $existing = Get-ADObject -SearchBase $somBase -LDAPFilter "(&(objectClass=msWMI-Som)(msWMI-Name=$wmiName))" -Properties 'msWMI-ID' -ErrorAction SilentlyContinue
    if ($existing) {
        $filterId = [string]$existing.'msWMI-ID'
        if ($filterId -notmatch '^\{') { $filterId = "{$filterId}" }
    }
    else {
        $bare = [guid]::NewGuid().ToString()
        $filterId = "{$bare}"
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss.ffffff-000')
        $parm2 = "1;3;10;$($wql.Length);WQL;root\CIMv2;$wql"
        New-ADObject -Name $bare -Type 'msWMI-Som' -Path $somBase -OtherAttributes @{
            'msWMI-Name'         = $wmiName
            'msWMI-Parm1'        = 'Workstations only. Excludes domain controllers and servers.'
            'msWMI-Parm2'        = $parm2
            'msWMI-Author'       = 'Seabed IT'
            'msWMI-ID'           = $filterId
            'msWMI-ChangeDate'   = $stamp
            'msWMI-CreationDate' = $stamp
        } | Out-Null
    }
    Set-ADObject -Identity $gpo.Path -Replace @{ gPCWQLFilter = "[$dns;$filterId;0]" }
}
else {
    try {
        Set-ADObject -Identity $gpo.Path -Clear gPCWQLFilter -ErrorAction Stop
    }
    catch {
        # No WMI filter was attached.
    }
}

Write-Step 'Linking the GPO'
$inheritance = Get-GPInheritance -Target $TargetDn
$link = @($inheritance.GpoLinks | Where-Object { $_.DisplayName -eq $GpoName })
$enforcedFlag = $(if ($Enforce) { 'Yes' } else { 'No' })
if ($link.Count -eq 0) {
    # Server 2016 GroupPolicy module requires -Enforced Yes|No, not a bare switch.
    New-GPLink -Name $GpoName -Target $TargetDn -LinkEnabled Yes -Enforced $enforcedFlag | Out-Null
}
else {
    Set-GPLink -Name $GpoName -Target $TargetDn -LinkEnabled Yes -Enforced $enforcedFlag | Out-Null
}

Write-Step 'Confirming Authenticated Users can read and apply the GPO'
$auth = (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-11')).Translate([System.Security.Principal.NTAccount]).Value
Set-GPPermission -Name $GpoName -TargetName $auth -TargetType Group -PermissionLevel GpoRead | Out-Null
Set-GPPermission -Name $GpoName -TargetName $auth -TargetType Group -PermissionLevel GpoApply | Out-Null

Write-Step 'Bumping the GPO version so clients pick this up'
$adGpo = Get-ADObject -Identity $gpo.Path -Properties versionNumber
$version = 0
if ($null -ne $adGpo.versionNumber) { $version = [int]$adGpo.versionNumber }
$userV = [math]::Floor($version / 65536)
$compV = $version - ($userV * 65536)
$userV = ($userV + 1) % 65536
$compV = ($compV + 1) % 65536
$newVersion = [int](($userV * 65536) + $compV)
Set-ADObject -Identity $gpo.Path -Replace @{ versionNumber = $newVersion }
$gptPath = Join-Path $policyPath 'GPT.INI'
$gpt = @(Get-Content -LiteralPath $gptPath -ErrorAction SilentlyContinue)
if ($gpt.Count -eq 0) { $gpt = @('[General]') }
$replaced = $false
$gpt = foreach ($line in $gpt) {
    if ($line -match '^\s*Version\s*=') { $replaced = $true; "Version=$newVersion" }
    else { $line }
}
if (-not $replaced) { $gpt += "Version=$newVersion" }
Set-Content -LiteralPath $gptPath -Value $gpt -Encoding Unicode

Write-Output ""
Write-Output "Linked. Version $newVersion."
Write-Output "Fonts install at the next startup. The asset folder copies at the next sign-in."
Write-Output "On a pilot PC: gpupdate /force, then restart, then sign in and run"
Write-Output "  \\$dns\SYSVOL\$dns\ErCon-Rebrand\Verify-ErConRebrand.ps1"
Write-Output "SYSVOL has to replicate before another site will see the files."
Write-Output "To take the link back off: .\Unlink-ErConRebrandGpo.ps1 -ConfirmDomainWide er-contech"
