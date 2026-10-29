# Er-Con rebrand — administrator installation

For Seabed IT. Requested by Ron Long. Needed well before 1 November 2026.

This is the procedure for putting the Er-Con fonts and the brand asset folder on every Windows computer joined to the er-contech Active Directory domain. Run it from a domain controller, or from a workstation that has RSAT. Do not run it from the web page. The page only builds the command and holds this document.

The script refuses any domain whose DNS name is not `er-contech` or `er-contech.<something>`, and whose NetBIOS name is not `ER-CONTECH`.

**Supported on Windows Server 2016** (Windows PowerShell 5.1) and later. No features newer than Server 2016 are required.

## What a finished PC looks like

After the computer restarts and the person signs in:

- Twelve static fonts are installed for the whole PC: Archivo, Source Sans 3, and IBM Plex Mono, each with Regular, Italic, Bold, and Bold Italic. No variable fonts. No SemiBold.
- Arial is still installed. This kit never deletes a font it did not put there, and it never deletes Arial.
- This folder exists:

  `C:\Users\<name>\Documents\Er-Con Rebrand Assets`

  That path is `%USERPROFILE%\Documents\Er-Con Rebrand Assets`. `%USERPROFILE%` already expands to `C:\Users\<name>`. Do not look for a folder literally named `%USERPROFILE%`.

- Inside that folder, matching the zip:

  - `Logos`
  - `Office Theme`
  - `Templates` (`Er-Con Template.potx`, `Er-Con Letterhead.dotx`)
  - `Er-Con Brand Standards.pdf`
  - `READ ME FIRST.md`

- The font files themselves are not copied into Documents. They are installed into `C:\Windows\Fonts` from the copy of the kit on SYSVOL.
- The same Logos, Office Theme, Templates, brand PDF, and readme also sit on a share at the root of D: on the server where you ran the deploy script:

  `D:\Er-Con Rebrand Assets`

  Shared as `\\<that server>\Er-Con Rebrand Assets`. Domain users can open it. They cannot change it. Domain Admins and local Administrators have full control.

Font embedding inside the two Office templates is already set. This procedure does not change it.

## What you need

- A domain administrator account in er-contech, or an account that can create a GPO, write its SYSVOL folder, and write the GPO object in Active Directory.
- Windows PowerShell 5.1. The command below uses `powershell.exe`, not PowerShell 7.
- On a member workstation instead of a domain controller: RSAT with Group Policy Management and the Active Directory module.
- Git (recommended) or the kit zip, `er-con-rebrand-gpo.zip`.
- One pilot PC that is joined to the domain, with a normal user who can sign in and open PowerPoint.
- A D: volume on the server where you run the deploy script. The share is created at `D:\Er-Con Rebrand Assets`. If the domain controller has no D:, create the share on the file server that does, then deploy the GPO with `-SkipAssetShare`.

## The shared folder

The deploy script creates this. You do not create the share by hand unless you are checking the result. It is a read-only copy of the brand files, separate from the per-user Documents folder. Group Policy still installs fonts and copies Documents from SYSVOL. The share is the place staff can open the templates directly, and the place you can confirm the files from any domain PC.

| | |
| --- | --- |
| Folder | `D:\Er-Con Rebrand Assets` |
| Share name | `Er-Con Rebrand Assets` |
| UNC | `\\<server you ran the script on>\Er-Con Rebrand Assets` |
| Caching | Off. Clients do not keep an offline copy. |

NTFS, inheritance removed, then these entries only:

| Account | NTFS |
| --- | --- |
| SYSTEM | Full control, this folder, subfolders, and files |
| Administrators | Full control, this folder, subfolders, and files |
| Domain Admins | Full control, this folder, subfolders, and files |
| Authenticated Users | Read and execute, this folder, subfolders, and files |

Share permissions, after the script replaces whatever Windows added by default:

| Account | Share |
| --- | --- |
| Administrators | Full |
| Domain Admins | Full |
| Authenticated Users | Read |

Everyone is not on the share. Users cannot add, edit, or delete files. A person who needs a working copy uses the folder in their own Documents, which the logon script maintains.

## Before you start

1. Pilot one OU before you link the domain. Startup scripts run as SYSTEM at boot. A mistake is domain-wide at the next restart.
2. Fonts do not install on `gpupdate` alone. Windows runs startup scripts at startup. Plan a restart.
3. The asset folder does not appear until that person signs in.
4. The GPO turns on “Always wait for the network at computer startup and logon”, runs startup scripts synchronously, and turns off the five-minute logon-script delay. Without those, the PC often runs the scripts before it can see SYSVOL and the fonts never show up. The cost is a longer boot when a laptop is off the network: Windows waits for the network before it continues. That wait is the Windows timeout, not a hang in this script.
5. If Documents is redirected by a Folder Redirection policy to a server path, this script still writes `%USERPROFILE%\Documents`. On a normal PC, and on a PC whose Documents folder was moved by OneDrive Known Folder Move, Explorer’s Documents folder is that path. If you use classic redirection and the local Documents folder is not the one staff open, say so before you roll this out.
6. An earlier build of this kit used `%USERPROFILE%\Er-Con Rebrand Assets` (the home folder, not Documents). If that folder exists from a test, delete it by hand. This version does not remove it.

## Step 1. Copy the kit to the domain controller

### Preferred: clone with Git

```powershell
# From an elevated PowerShell, choose a clean location (recommended)
cd C:\Tools
git clone https://github.com/Ercontech/er-con-rebrand-kit.git
cd er-con-rebrand-kit
```

Or, if you already cloned elsewhere (for example under `C:\Windows\system32`):

```powershell
cd C:\Windows\system32\er-con-rebrand-kit
```

### Alternative: zip

1. Download `er-con-rebrand-gpo.zip`.
2. Copy it to the domain controller. A local disk is fine. Do not unzip it straight into SYSVOL. The deploy script copies the payload there.
3. Unzip it. You should have a folder named `ErCon-Rebrand-GPO` containing the same files as the Git clone.

4. Confirm `payload\Assets\Fonts to install` contains twelve files and nothing else you intend to install. The install script ignores any font that is not one of those twelve, including Archivo SemiBold.

## Step 2. Open an elevated Windows PowerShell and change to the kit folder

1. Sign in to the domain controller with the admin account.
2. Right-click **Windows PowerShell** and choose **Run as administrator**. Do not use PowerShell 7 (`pwsh.exe`) for this procedure.
3. Change to the kit folder. The prompt must be inside the folder that contains `Deploy-ErConRebrandGpo.ps1`.

```powershell
Set-Location C:\Tools\er-con-rebrand-kit
# or
Set-Location C:\Windows\system32\er-con-rebrand-kit

# Confirm
dir Deploy-ErConRebrandGpo.ps1
```

If you skip this step and run from `C:\Windows\system32` you will see:

```
The argument '.\Deploy-ErConRebrandGpo.ps1' to the -File parameter does not exist.
Provide the path to an existing '.ps1' file as an argument to the -File parameter.
```

That error means the current directory is wrong. `cd` into the kit folder and try again.

## Step 3. Confirm this is the er-contech domain

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DistinguishedName
```

Write down the three values.

| Field | Required |
| --- | --- |
| DNSRoot | `er-contech` or `er-contech.` plus a suffix, for example `er-contech.local` |
| NetBIOSName | `ER-CONTECH` |
| DistinguishedName | The domain root, for example `DC=er-contech,DC=local` |

If DNS is not an er-contech name and NetBIOS is not `ER-CONTECH`, stop. The script will refuse, and it should.

## Step 4. Pilot one OU first

Find the pilot OU’s distinguished name:

```powershell
Get-ADOrganizationalUnit -Filter 'Name -like "*Pilot*"' |
  Select-Object Name, DistinguishedName
```

If the name search misses it, list them:

```powershell
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName
```

Move one test computer into that OU, or pick an OU that already holds only the test PC. Then run, replacing the distinguished name:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Deploy-ErConRebrandGpo.ps1 -ConfirmDomainWide er-contech -TargetDn "OU=Pilot,DC=er-contech,DC=local"
```

`-ConfirmDomainWide er-contech` is required even for a pilot. It is the confirmation that you mean this domain, not a switch that skips the OU and hits every PC. The OU in `-TargetDn` is what limits the pilot.

Optional, if you want the script to stop unless the DNS name matches exactly what Step 3 printed:

```powershell
-ExpectedDnsName "er-contech.local"
```

Leave `-WorkstationsOnly` off for the pilot unless that OU contains a server you must exclude. Leave enforce on.

Before you press Enter, confirm this server has a D: drive:

```powershell
Get-PSDrive -Name D
```

If that fails, do not run the command above on this machine. On the server that has D:, from this same unzipped folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\New-ErConAssetShare.ps1 -ConfirmDomainWide er-contech -SourceAssets .\payload\Assets
```

Then run the deploy command on the domain controller and add `-SkipAssetShare`.

## Step 5. Read the script output

The script prints a step name before each action. The first action creates `D:\Er-Con Rebrand Assets` and the share, unless you passed `-SkipAssetShare`. A successful run ends with `Linked.` plus a version number, the SYSVOL path of `Verify-ErConRebrand.ps1`, and a reminder that another site will not see the files until SYSVOL replicates.

It does all of the following. You do not click these in GPMC.

1. Creates `D:\Er-Con Rebrand Assets`, copies Logos, Office Theme, Templates, the brand PDF, and the readme into it, and shares that folder.
2. Copies `payload` to `\\<dns>\SYSVOL\<dns>\ErCon-Rebrand`.
3. Creates the GPO **Er-Con Rebrand - Fonts and Assets** if it does not exist.
4. Writes a computer startup script, `Launch-Install-ErConFonts.ps1`, which runs `Install-ErConFonts.ps1` from that SYSVOL folder as SYSTEM.
5. Writes a user logon script, `Launch-Copy-ErConAssets.ps1`, which runs `Copy-ErConAssets.ps1`.
6. Sets three policies on that GPO:
   - Always wait for the network (`SyncForegroundPolicy` = 1).
   - Run startup scripts synchronously (`RunStartupScriptSync` = 1). Windows waits until the font install finishes.
   - Logon script delay off (`EnableLogonScriptDelay` = 0). The Documents folder is copied at sign-in, not five minutes later.
7. Gives Authenticated Users permission to read and apply the GPO.
8. Links the GPO at the target you named. With no `-TargetDn`, that target is the domain root. The link is enforced unless you passed `-Enforce:$false`.
9. Bumps the GPO version so clients treat it as a change.

Write down the UNC the share step prints. It looks like `\\FILESERVER\Er-Con Rebrand Assets`. You need that name when you test from a PC.

If it throws before `Linked.`, do not reboot the pilot yet. Fix the message and run the same command again. Running it again updates the same GPO. It does not create a second one.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `The argument '.\Deploy-ErConRebrandGpo.ps1' to the -File parameter does not exist` | Current directory is not the kit folder | `cd` to the folder that contains the script, then retry |
| Script throws “payload\fonts.manifest.json is missing” | Same as above, or incomplete clone/unzip | Confirm `dir payload\fonts.manifest.json` succeeds |
| Script refuses the domain | DNS or NetBIOS does not match | Run `Get-ADDomain` and verify |
| Fonts never appear after gpupdate | Startup scripts run only at startup | Restart the pilot PC |
| Documents folder missing | User has not signed in since the GPO applied | Sign out and sign in again as a domain user |
| Share too open | Manual ACL change or earlier run | Re-run `New-ErConAssetShare.ps1` |

Logs after a successful pilot:

- `C:\ProgramData\Er-Con\rebrand-fonts.log` (startup / fonts)
- `%LOCALAPPDATA%\Er-Con\rebrand-assets.log` (logon / Documents)

Continue with the existing verification steps (share check, GPMC, SYSVOL, and the full domain-PC test in the original document structure). The critical path error is fixed by Step 2 above.
