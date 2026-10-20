# Er-Con rebrand kit

Deploys the Er-Con fonts, logos, Office templates, and the written instructions to every Authenticated User on a Windows computer joined to the **er-contech** Active Directory domain.

Requested by Ron Long. Needed well before 1 November 2026. Seabed IT runs it. This repository is the source. Clone it onto the server and run it from the clone. Do not re-zip it unless the domain controller has no Git.

This file is the map. The click-by-click procedure is [ADMIN-INSTALLATION.md](ADMIN-INSTALLATION.md). Rules a coding agent must not break are in [AGENTS.md](AGENTS.md).

## What a finished PC looks like

After the computer restarts and the person signs in:

- Twelve static fonts are installed for the whole PC. Arial is still installed.
- `%USERPROFILE%\Documents\Er-Con Rebrand Assets` exists. On a normal PC that is `C:\Users\<name>\Documents\Er-Con Rebrand Assets`.
- That folder holds `Logos`, `Office Theme`, `Templates`, `Er-Con Brand Standards.pdf`, and `READ ME FIRST.md`.
- The same five items are on `D:\Er-Con Rebrand Assets` of the server that ran the deploy, shared as `\\<that server>\Er-Con Rebrand Assets`. Authenticated Users can read. They cannot change the files.

| Family | Faces | Files |
| --- | --- | --- |
| Archivo | Regular, Italic, Bold, Bold Italic | `payload/Assets/Fonts to install/Archivo/` |
| Source Sans 3 | Regular, Italic, Bold, Bold Italic | `payload/Assets/Fonts to install/Source Sans 3/` |
| IBM Plex Mono | Regular, Italic, Bold, Bold Italic | `payload/Assets/Fonts to install/IBM Plex Mono/` |

No other weight. No variable font. Archivo SemiBold is not in this kit. Font embedding inside `Er-Con Template.potx` and `Er-Con Letterhead.dotx` is already set. Nothing here changes it.

## What you run

On a domain controller, or a workstation with RSAT, elevated **Windows PowerShell 5.1** in this folder. The server that creates the share must have a `D:` volume. If it does not, read the `-SkipAssetShare` note in [ADMIN-INSTALLATION.md](ADMIN-INSTALLATION.md) before you continue.

Pilot one OU first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Deploy-ErConRebrandGpo.ps1 -ConfirmDomainWide er-contech -TargetDn "OU=Pilot,DC=er-contech,DC=local"
```

After that PC passes the test in the admin document, link the domain:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Deploy-ErConRebrandGpo.ps1 -ConfirmDomainWide er-contech
```

`-ConfirmDomainWide er-contech` is required every time. It is not a shortcut that skips the OU. The script refuses a machine whose DNS name is not `er-contech` or `er-contech.<suffix>` and whose NetBIOS name is not `ER-CONTECH`.

The script:

1. Creates `D:\Er-Con Rebrand Assets`, copies the staff files into it, and shares it read-only to Authenticated Users.
2. Copies `payload\` to `\\<dns>\SYSVOL\<dns>\ErCon-Rebrand`.
3. Creates or updates the GPO **Er-Con Rebrand - Fonts and Assets**, enforced, security-filtered to Authenticated Users (read and apply).
4. Computer startup runs `Install-ErConFonts.ps1` as SYSTEM.
5. User logon runs `Copy-ErConAssets.ps1` and mirrors the staff files into Documents.
6. Turns on “always wait for the network”, runs startup scripts synchronously, and turns off the five-minute logon-script delay.

Fonts appear at the next restart. The Documents folder appears at the next sign-in. `gpupdate` alone does neither.

Take the link off without deleting fonts:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Unlink-ErConRebrandGpo.ps1 -ConfirmDomainWide er-contech
```

## Layout

```
Deploy-ErConRebrandGpo.ps1     Creates the share, copies SYSVOL, links the GPO
New-ErConAssetShare.ps1        D:\ folder, NTFS ACL, SMB share. Called by Deploy
Unlink-ErConRebrandGpo.ps1     Disables the link. Does not uninstall fonts
ADMIN-INSTALLATION.md          Operator procedure, including the domain-PC test
AGENTS.md                      Constraints for a coding agent
payload\
  Install-ErConFonts.ps1       Startup. Twelve faces, hash-checked, Arial untouched
  Copy-ErConAssets.ps1         Logon. Documents folder. Does not copy the font files
  Verify-ErConRebrand.ps1      Run on the test PC after restart and sign-in
  Remove-ErConFonts.ps1        Uninstalls a face only when its hash still matches
  fonts.manifest.json          File name, name-ID-4 full name, SHA-256
  Assets\                      Logos, Office Theme, Templates, PDF, readme, fonts
scripts\check-kit.py           Local check. No domain required
```

Group Policy launches thin stubs, `Launch-Install-ErConFonts.ps1` and `Launch-Copy-ErConAssets.ps1`, which the deploy script writes into the GPO folder. Those stubs find SYSVOL from the computer’s domain name. Edit the payload scripts, not a copy you find later under SYSVOL. The next deploy overwrites SYSVOL from this tree.

## Permissions

| Who | GPO | Share | NTFS on `D:\Er-Con Rebrand Assets` |
| --- | --- | --- | --- |
| Authenticated Users | Read and apply | Read | Read and execute |
| Domain Admins | (implicit via Administrators on a DC) | Full | Full control |
| Administrators | — | Full | Full control |
| SYSTEM | Runs the startup script | — | Full control |

Everyone is not on the share. Inheritance on the folder is removed so a loose ACL on `D:\` does not leak in.

## Out of scope

- Macs. Jamf or Intune, from the original request, is a different package.
- Windows devices that are not joined to er-contech. Entra-only PCs do not process this GPO.
- Removing Arial, Calibri, or any font this kit did not install.
- Word for Mac font embedding on perpetual Office 2021. Final documents still go out as PDF.

## Changing the kit

1. Change the script or the file under `payload\Assets`.
2. If you add, remove, or replace a `.ttf`, regenerate `payload/fonts.manifest.json` (see [AGENTS.md](AGENTS.md)). The startup script skips a file whose SHA-256 does not match.
3. Run `python3 scripts/check-kit.py` from this folder. It must pass before you deploy.
4. If an operator step changed, edit [ADMIN-INSTALLATION.md](ADMIN-INSTALLATION.md) in the same change.
5. Re-run `Deploy-ErConRebrandGpo.ps1` on the domain. It updates the same GPO and the same share. It does not create a second GPO.

Licenses for the three families are the OFL files next to the fonts. Do not strip them.
