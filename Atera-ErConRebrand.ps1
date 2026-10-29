# Atera / RMM script: install Er-Con fonts and copy rebrand assets.
# Does not use Group Policy. Safe to re-run. Does not remove Arial.
#
# Run as SYSTEM (recommended in Atera) so fonts install machine-wide.
# Assets are copied into every currently logged-on user's Documents folder.
# If no user is logged on, fonts still install; assets are skipped with a clear message.
#
# Source kit (already on SYSVOL from the deploy script):
#   \\ER-CONTECH.local\SYSVOL\ER-CONTECH.local\ErCon-Rebrand
#
# Exit codes: 0 = success, 1 = one or more steps failed.
#Requires -Version 5.1
$ErrorActionPreference = 'Continue'

$KitRoot = '\\ER-CONTECH.local\SYSVOL\ER-CONTECH.local\ErCon-Rebrand'
$LogDir  = Join-Path $env:ProgramData 'Er-Con'
$Log     = Join-Path $LogDir 'atera-rebrand.log'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log([string]$Message) {
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $Log -Value $line -Encoding UTF8
    Write-Output $line
}

$failed = $false

Write-Log "=== Atera Er-Con rebrand start on $env:COMPUTERNAME ==="
Write-Log "Kit root: $KitRoot"

# ---------------------------------------------------------------------------
# 1. Fonts (machine-wide). Reuses the kit's own installer.
# ---------------------------------------------------------------------------
$fontScript = Join-Path $KitRoot 'Install-ErConFonts.ps1'
if (-not (Test-Path -LiteralPath $fontScript)) {
    Write-Log "FAIL: Install-ErConFonts.ps1 not found at $fontScript"
    $failed = $true
}
else {
    Write-Log 'Running Install-ErConFonts.ps1 (SYSTEM / machine-wide)'
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fontScript
        if ($LASTEXITCODE -eq 0) {
            Write-Log 'Fonts: OK'
        }
        else {
            Write-Log "Fonts: installer exited $LASTEXITCODE"
            $failed = $true
        }
    }
    catch {
        Write-Log ("Fonts ERROR: " + $_.Exception.Message)
        $failed = $true
    }
}

# ---------------------------------------------------------------------------
# 2. Assets into each logged-on user's Documents\Er-Con Rebrand Assets
# ---------------------------------------------------------------------------
$assetScript = Join-Path $KitRoot 'Copy-ErConAssets.ps1'
$srcAssets   = Join-Path $KitRoot 'Assets'

if (-not (Test-Path -LiteralPath $srcAssets)) {
    Write-Log "FAIL: Assets folder not found at $srcAssets"
    $failed = $true
}
else {
    # Logged-on users (interactive sessions)
    $users = @()
    try {
        $q = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        # Also enumerate explorer.exe owners for accuracy
        $explorers = Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue
        foreach ($p in $explorers) {
            $owner = Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction SilentlyContinue
            if ($owner.User) {
                $users += [PSCustomObject]@{
                    User   = $owner.User
                    Domain = $owner.Domain
                }
            }
        }
        $users = $users | Sort-Object User, Domain -Unique
    }
    catch {
        Write-Log ("Could not enumerate logged-on users: " + $_.Exception.Message)
    }

    if ($users.Count -eq 0) {
        Write-Log 'No interactive user logged on. Fonts installed; assets will copy at next logon via GPO or a later Atera run.'
    }
    else {
        foreach ($u in $users) {
            $profile = $null
            try {
                # Resolve profile path from the registry (works for domain users)
                $sid = (New-Object System.Security.Principal.NTAccount("$($u.Domain)\$($u.User)")).Translate([System.Security.Principal.SecurityIdentifier]).Value
                $profile = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
            }
            catch {
                Write-Log "Could not resolve profile for $($u.Domain)\$($u.User): $($_.Exception.Message)"
                continue
            }

            $docs = Join-Path $profile 'Documents'
            $dst  = Join-Path $docs 'Er-Con Rebrand Assets'
            if (-not (Test-Path -LiteralPath $docs)) {
                Write-Log "Documents folder missing for $($u.User): $docs"
                continue
            }

            Write-Log "Copying assets for $($u.Domain)\$($u.User) -> $dst"
            New-Item -ItemType Directory -Force -Path $dst | Out-Null
            & robocopy.exe $srcAssets $dst /MIR /XD "Fonts to install" /R:2 /W:2 /NFL /NDL /NP /XJ
            $code = $LASTEXITCODE
            if ($code -ge 8) {
                Write-Log "robocopy failed for $($u.User) with $code"
                $failed = $true
            }
            else {
                Write-Log "Assets OK for $($u.User) (robocopy $code)"
            }
        }
    }
}

# ---------------------------------------------------------------------------
# 3. Summary
# ---------------------------------------------------------------------------
$fontLog = Join-Path $LogDir 'fonts-installed.json'
if (Test-Path -LiteralPath $fontLog) {
    Write-Log ("Font summary: " + (Get-Content -LiteralPath $fontLog -Raw))
}

if ($failed) {
    Write-Log '=== Finished with errors. See log above. ==='
    exit 1
}
else {
    Write-Log '=== Finished successfully. ==='
    exit 0
}
