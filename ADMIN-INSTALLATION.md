# Er-Con rebrand — administrator installation

For Seabed IT. Requested by Ron Long. Needed well before 1 November 2026.

This is the procedure for putting the Er-Con fonts and the brand asset folder on every Windows computer joined to the er-contech Active Directory domain. Run it from a domain controller, or from a workstation that has RSAT. Do not run it from the web page. The page only builds the command and holds this document.

The script refuses any domain whose DNS name is not `er-contech` or `er-contech.<something>`, and whose NetBIOS name is not `ER-CONTECH`.

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
- The kit zip, `er-con-rebrand-gpo.zip`.
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

1. Download `er-con-rebrand-gpo.zip`.
2. Copy it to the domain controller. A local disk is fine. Do not unzip it straight into SYSVOL. The deploy script copies the payload there.
3. Unzip it. You should have a folder named `ErCon-Rebrand-GPO` containing:

```
ErCon-Rebrand-GPO\
  ADMIN-INSTALLATION.md
  README-FOR-SEABED-IT.md
  Deploy-ErConRebrandGpo.ps1
  New-ErConAssetShare.ps1
  Unlink-ErConRebrandGpo.ps1
  payload\
    Install-ErConFonts.ps1
    Copy-ErConAssets.ps1
    Verify-ErConRebrand.ps1
    Remove-ErConFonts.ps1
    fonts.manifest.json
    Assets\
      Logos\
      Office Theme\
      Templates\
      Er-Con Brand Standards.pdf
      READ ME FIRST.md
      Fonts to install\     (twelve .ttf files)
```

4. Confirm `payload\Assets\Fonts to install` contains twelve files and nothing else you intend to install. The install script ignores any font that is not one of those twelve, including Archivo SemiBold.

## Step 2. Open an elevated Windows PowerShell

1. Sign in to the domain controller with the admin account.
2. Right-click **Windows PowerShell** and choose **Run as administrator**. Do not use PowerShell 7 (`pwsh.exe`) for this procedure.
3. Change to the unzipped folder:

```
Set-Location C:\Path\You\Unzipped\ErCon-Rebrand-GPO
```

Use the real path. The prompt must be inside the folder that contains `Deploy-ErConRebrandGpo.ps1`.

## Step 3. Confirm this is the er-contech domain

```
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

```
Get-ADOrganizationalUnit -Filter 'Name -like "*Pilot*"' |
  Select-Object Name, DistinguishedName
```

If the name search misses it, list them:

```
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName
```

Move one test computer into that OU, or pick an OU that already holds only the test PC. Then run, replacing the distinguished name:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Deploy-ErConRebrandGpo.ps1 -ConfirmDomainWide er-contech -TargetDn "OU=Pilot,DC=er-contech,DC=local"
```

`-ConfirmDomainWide er-contech` is required even for a pilot. It is the confirmation that you mean this domain, not a switch that skips the OU and hits every PC. The OU in `-TargetDn` is what limits the pilot.

Optional, if you want the script to stop unless the DNS name matches exactly what Step 3 printed:

```
-ExpectedDnsName "er-contech.local"
```

Leave `-WorkstationsOnly` off for the pilot unless that OU contains a server you must exclude. Leave enforce on.

Before you press Enter, confirm this server has a D: drive:

```
Get-PSDrive -Name D
```

If that fails, do not run the command above on this machine. On the server that has D:, from this same unzipped folder:

```
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

## Step 6. Check the share on the server

On the server where D: lives:

1. Open File Explorer and go to `D:\`. You should see the folder `Er-Con Rebrand Assets` at the root, not inside another folder.
2. Open it. You should see `Logos`, `Office Theme`, `Templates`, `Er-Con Brand Standards.pdf`, and `READ ME FIRST.md`. You should not see `Fonts to install`.
3. Right-click the folder, **Properties**, **Security**. Inheritance is disabled. The list is SYSTEM, Administrators, Domain Admins, and Authenticated Users. Authenticated Users is Read & execute. There is no Modify for users.
4. Open **Computer Management** (`compmgmt.msc`) → **Shared Folders** → **Shares**.
5. Open **Er-Con Rebrand Assets** → **Properties** → **Share Permissions**. Administrators Full, Domain Admins Full, Authenticated Users Read. Everyone is not listed.
6. From an elevated PowerShell prompt on that server:

```
Get-SmbShare -Name 'Er-Con Rebrand Assets' | Format-List Name, Path, CachingMode
Get-SmbShareAccess -Name 'Er-Con Rebrand Assets' | Format-Table AccountName, AccessControlType, AccessRight
icacls "D:\Er-Con Rebrand Assets"
```

`Path` must be `D:\Er-Con Rebrand Assets`. `CachingMode` must be `None`.

## Step 7. Check the GPO in Group Policy Management

1. On the domain controller, press Win+R, type `gpmc.msc`, and press Enter.
2. Expand **Forest: er-contech…** → **Domains** → the er-contech domain.
3. If you piloted an OU, click that OU. The right pane, **Linked Group Policy Objects**, must list **Er-Con Rebrand - Fonts and Assets**. The Enforced column is Yes, and the Link Enabled column is Yes.
4. If you linked the domain, click the domain itself and check the same list there.
5. Click the GPO link. On the **Scope** tab:
   - **Links** shows the OU or the domain.
   - **Security Filtering** contains **Authenticated Users**.
   - **WMI Filtering** is **None**, unless you passed `-WorkstationsOnly`. In that case it is **Er-Con Rebrand - Windows workstations only**.
6. Open the **Delegation** tab and confirm **Authenticated Users** has **Read** (the apply right is shown as the filtering on Scope). Do not remove Authenticated Users from Delegation. On current Windows that stops the GPO from applying.
7. Click the **Settings** tab and wait for the report. Under **Computer Configuration** you should see extra registry settings:
   - `Software\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon` → `SyncForegroundPolicy` = 1
   - `Software\Microsoft\Windows\CurrentVersion\Policies\System` → `RunStartupScriptSync` = 1
   - `Software\Policies\Microsoft\Windows\System` → `EnableLogonScriptDelay` = 0
   - `Software\Er-Con\Rebrand` → `Kit` and `Scope`
   These are written straight into the GPO. They may appear as extra registry settings rather than as named Administrative Template titles. That is expected.
8. Under **User Configuration** the report shows a logon script. Under **Computer Configuration** it shows a startup script.
9. Right-click the GPO under **Group Policy Objects** (not the link) and choose **Edit**.
10. Go to **Computer Configuration** → **Policies** → **Windows Settings** → **Scripts (Startup/Shutdown)**.
11. Double-click **Startup**. Open the **PowerShell Scripts** tab. There is one script: `Launch-Install-ErConFonts.ps1`. There is nothing on the Scripts tab. Do not add a second script.
12. Go to **User Configuration** → **Policies** → **Windows Settings** → **Scripts (Logon/Logoff)**.
13. Double-click **Logon**. Open the **PowerShell Scripts** tab. There is one script: `Launch-Copy-ErConAssets.ps1`. Close the editor without changing anything.

## Step 8. Let SYSVOL replicate

On a single domain controller this is immediate. With more than one, wait until the other controllers have `\\<dns>\SYSVOL\<dns>\ErCon-Rebrand\Install-ErConFonts.ps1`.

From an elevated prompt on the domain controller:

```
repadmin /syncall /AdeP
```

Then, on a PC in the pilot OU, confirm the SYSVOL folder opens:

```
dir \\er-contech.local\SYSVOL\er-contech.local\ErCon-Rebrand
```

Use the DNS name from Step 3, not this example, if yours is different.

## Step 9. Test on a domain computer

Test on a workstation that is joined to er-contech and sits in the OU you linked. Do not call the job done from the domain controller console. A domain controller is not a normal user desktop, and restarting it drops the domain for a moment.

Sign in to the test PC with a domain account. A local account does not process this user script and does not have a domain profile.

### 9.1 Prove the PC is in the domain and in the OU

Open Windows PowerShell and run:

```
Get-CimInstance Win32_ComputerSystem | Select-Object Name, Domain, PartOfDomain
```

`PartOfDomain` must be `True`. `Domain` must be the DNS name from Step 3.

Then:

```
gpresult /r
```

Under **Computer Settings**, the **CN=** line shows the OU. It must be the pilot OU, or the domain, if you already linked the domain. Under **Applied Group Policy Objects** you may not see the new GPO yet. That is fine before `gpupdate`.

### 9.2 Pull the policy

Open a command prompt **as administrator**:

```
gpupdate /force
```

Wait until you see both of these lines:

```
Computer Policy update has completed successfully.
User Policy update has completed successfully.
```

If the user half fails with “The processing of Group Policy failed”, the person is not a domain user, or the PC cannot reach a domain controller. Stop and fix that before you restart.

### 9.3 Restart, then sign in as the test user

Restart from the Start menu. Do not only sign out. Startup scripts run at startup.

Sign in again as the same domain user. The first sign-in after the restart is the one that creates the Documents folder. Give it a minute on a slow link. The logon script is set to run immediately, not five minutes later.

### 9.4 Prove the GPO applied to this PC and this user

In a normal (not elevated) PowerShell window:

```
gpresult /h $env:USERPROFILE\Desktop\ercon-gp.html
```

Open `ercon-gp.html` from the desktop.

- Under **Computer Details** → **Applied GPOs**, find **Er-Con Rebrand - Fonts and Assets**.
- Under **User Details** → **Applied GPOs**, find the same name.
- If it is listed under **Denied GPOs**, read the reason. “Empty” means the script client-side extension was not registered. Run the deploy script again. “Security filtering” or “WMI filter” means this PC is outside the scope you set.

### 9.5 Prove the fonts

Still on the test PC:

```
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' |
  Select-String -Pattern 'Archivo|Source Sans 3|IBM Plex Mono|Arial'
```

You want twelve Er-Con names (Regular, Italic, Bold, Bold Italic for each family) and at least one Arial entry. You do not want Archivo SemiBold.

In Explorer, open `C:\Windows\Fonts` and confirm the twelve files are there. Then open **Settings → Personalization → Fonts** and search Archivo, Source Sans 3, and IBM Plex Mono. Arial must still be in the list.

### 9.6 Prove the Documents folder

In Explorer, paste this into the address bar:

```
%USERPROFILE%\Documents\Er-Con Rebrand Assets
```

You should land in `C:\Users\<the signed-in user>\Documents\Er-Con Rebrand Assets` and see:

- `Logos`
- `Office Theme`
- `Templates`
- `Er-Con Brand Standards.pdf`
- `READ ME FIRST.md`

You should not see `Fonts to install`.

### 9.7 Prove the D: share, from this PC

Use the server name the deploy script printed. Do not look for the folder on D: of the workstation. The workstation has the Documents copy. The share lives on the server.

```
dir "\\FILESERVER\Er-Con Rebrand Assets"
```

The listing matches the Documents folder. Then prove the user cannot change it. This must fail with access denied:

```
New-Item "\\FILESERVER\Er-Con Rebrand Assets\delete-me.txt" -ItemType File
```

If that file is created, the share is too open. Remove the file and run `New-ErConAssetShare.ps1` again on the server.

Open `Templates\Er-Con Letterhead.dotx` from the share. It should open in Word.

### 9.8 Prove Office

1. From the Documents folder, open `Templates\Er-Con Template.potx`. It should not ask to repair the file. Start a deck.
2. The font menu shows Archivo, Source Sans 3, and IBM Plex Mono. One entry each, with Regular, Italic, Bold, and Bold Italic. Archivo SemiBold as its own family means an extra file was installed. This kit does not contain SemiBold.
3. Design → Colors shows the Er-Con set. Signal ramp 1 through 4 is blue.
4. Save a test `.docx` and open it on a PC that does not have these fonts. Headings should still be Archivo and body text should still be Source Sans 3.
5. Arial is still in the font menu.

### 9.9 Run the verifier

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "\\er-contech.local\SYSVOL\er-contech.local\ErCon-Rebrand\Verify-ErConRebrand.ps1"
```

Use the DNS name from Step 3. Zero failed checks is the machine result. The Office checks in 9.8 are still done by eye.

### 9.10 If something failed

| What you see | Where to look | What it usually means |
| --- | --- | --- |
| Fonts missing after `gpupdate`, no restart | — | Expected. Restart the PC. |
| Fonts missing after a restart | `C:\ProgramData\Er-Con\rebrand-fonts.log` | The startup script could not read SYSVOL, or it ran before the network. Confirm Step 8, then restart once more. |
| Documents folder missing after sign-in | `%LOCALAPPDATA%\Er-Con\rebrand-assets.log` | The logon script could not read SYSVOL. The existing folder, if any, is left as it was. |
| GPO missing from `gpresult` | `ercon-gp.html` on the desktop | The PC is outside the OU, or SYSVOL has not replicated to the DC this PC is talking to. |
| Share not found | The UNC from Step 5 | You are using the wrong server name, or the deploy ran with `-SkipAssetShare` and the share script has not been run. |
| User could create a file on the share | Share Permissions in Computer Management | Run `New-ErConAssetShare.ps1` again. It replaces the access list. |
| Verifier says SemiBold is registered | The font list on that PC | Some other package installed Archivo SemiBold. This kit will not remove it. |
| “Refusing to deploy” | The PowerShell window on the server | This machine is not in the er-contech domain. |

If the scripts never start at all, on the test PC open **Event Viewer → Applications and Services Logs → Microsoft → Windows → GroupPolicy → Operational** and read the events from the last startup.

## Step 10. Link the rest of the domain

When the test PC passes 9.4 through 9.9, run the same script with no `-TargetDn`. This links the same GPO at the domain root, enforced, for every Windows computer that applies Group Policy, including servers and domain controllers. The share is not created again as a second share. The script refreshes the same `D:\Er-Con Rebrand Assets` folder.

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Deploy-ErConRebrandGpo.ps1 -ConfirmDomainWide er-contech
```

If you also want to keep the pilot OU link, leave it. The domain link covers that OU too. You can unlink the pilot OU in Group Policy Management after the domain link is in place. Do not delete the GPO.

Servers and domain controllers are included because the request was every Windows device in the domain. To leave them out, add `-WorkstationsOnly`. That attaches a WMI filter for `ProductType = 1` (workstations). Domain controllers and member servers do not get the GPO.

To link it without the Enforced flag:

```
-Enforce:$false
```

An OU that blocks inheritance will then not receive it. The request was every device, so leave enforce on unless you have a reason not to.

Each remaining PC gets the fonts at its next restart and the Documents folder at the next sign-in. Tell staff they need one restart. A shutdown overnight is enough.

## Step 11. What this does not cover

- Macs. Use the Jamf or Intune package path from the original request.
- Windows PCs that are not joined to the er-contech domain. A device joined only to Entra ID does not process this GPO.
- Removing Arial, Calibri, or any font that was already on the PC.
- Word for Mac font embedding on perpetual Office 2021. Microsoft documents that as Microsoft 365 only. PowerPoint for Mac lists 365, 2024, and 2021. Anyone authoring on a perpetual Mac licence should send PDFs for anything final.

## Step 12. Taking it back

From the same `ErCon-Rebrand-GPO` folder, elevated:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Unlink-ErConRebrandGpo.ps1 -ConfirmDomainWide er-contech
```

That disables the domain link. The GPO remains. Fonts already installed on a PC stay installed. The Documents folder stays. The share on D: stays. To remove the share, on that server:

```
Remove-SmbShare -Name 'Er-Con Rebrand Assets' -Force
Remove-Item -LiteralPath 'D:\Er-Con Rebrand Assets' -Recurse -Force
```

Do that only when nobody should open the templates from the network anymore.

To remove the twelve faces from one PC, copy `payload\Remove-ErConFonts.ps1` and `payload\fonts.manifest.json` to that PC and run the script as administrator. It deletes a file only when the hash still matches this kit. It does not delete Arial. Add `-RemoveProfileCopy` to also delete that user’s `Documents\Er-Con Rebrand Assets`. It does not delete any other user’s copy.

These two switches are separate and are not part of a normal rollback:

- `-DeleteGpo` removes the link and deletes the GPO.
- `-DeleteSysvolPayload` deletes `\\<dns>\SYSVOL\<dns>\ErCon-Rebrand`.

Do not use either one while you still want the fonts to repair themselves at the next startup.

## Step 13. Sign-off

| Check | Pilot | Domain |
| --- | --- | --- |
| `Get-ADDomain` shows er-contech | | |
| Deploy script printed `Linked.` | | |
| `D:\Er-Con Rebrand Assets` exists and is shared | | |
| From the test PC, the UNC opens and a new file is denied | | |
| GPO linked, enforced, Authenticated Users can apply | | |
| SYSVOL folder visible from the pilot PC | | |
| `gpupdate /force`, restart, sign-in | | |
| Verifier reported 0 failed | | |
| Documents folder has Logos, Office Theme, Templates, the PDF, and the readme | | |
| Template opens with no repair prompt | | |
| Three families, four faces, no SemiBold | | |
| Er-Con colors, signal ramp blue | | |
| Test document still renders on a PC without the fonts | | |
| Arial still present | | |
| Domain link created only after the pilot passed | | |

Record the date, the domain controller you ran it on, and the DNS name. The rollout has to be finished well before 1 November 2026.
