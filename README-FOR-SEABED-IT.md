# Er-Con rebrand — Group Policy for the er-contech domain

For Seabed IT. Requested by Ron Long. Needed well before 1 November 2026.

The step-by-step procedure is [ADMIN-INSTALLATION.md](ADMIN-INSTALLATION.md) in this folder. Use that document on the domain controller. This file is the short version.

This kit installs three static font families on every Windows computer joined to
the er-contech domain, and copies the rebrand asset folder into each person's
Documents folder. It is an addition. Arial stays installed.

The font files in this kit are the twelve files from `Fonts to install/` in
Er-Con Rebrand Assets.zip. They are static faces, not the variable fonts from
Google Fonts. No other weights are included. Archivo SemiBold is not in this kit.

## What you run

On a domain controller, or on a workstation with RSAT (Group Policy and Active
Directory), open an elevated Windows PowerShell in this folder:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Deploy-ErConRebrandGpo.ps1 -ConfirmDomainWide er-contech
```

The script stops immediately if the domain's DNS name is not `er-contech` or
`er-contech.<suffix>`, and the NetBIOS name is not `ER-CONTECH`.

That command:

1. Copies this payload to `\\<dns>\SYSVOL\<dns>\ErCon-Rebrand`.
2. Creates the GPO **Er-Con Rebrand - Fonts and Assets** if it does not exist.
3. Links it at the domain root, enforced, so an OU that blocks inheritance still gets it.
4. Computer startup runs `Install-ErConFonts.ps1` as SYSTEM.
5. User logon runs `Copy-ErConAssets.ps1`, which mirrors Logos, Office Theme, Templates, the brand standards PDF, and READ ME FIRST.md into `%USERPROFILE%\Documents\Er-Con Rebrand Assets`. On a normal PC that is `C:\Users\<name>\Documents\Er-Con Rebrand Assets`. The font files are installed for the machine and are not copied into Documents.
6. Turns on "always wait for the network", runs startup scripts synchronously, and turns off the five-minute logon-script delay. Without those, the scripts often run before SYSVOL is reachable and the fonts never appear.
7. Does not delete Arial, does not install a variable font, and skips any extra font file that is not one of the twelve.
8. Creates `D:\Er-Con Rebrand Assets` on the server where you run it, and shares that folder as `Er-Con Rebrand Assets`. Authenticated Users have Read. Domain Admins and Administrators have Full Control. Pass `-SkipAssetShare` if this server has no D: and you already created the share on the file server.

Optional switches:

- `-ExpectedDnsName er-contech.local` — stop if this DC's DNS name is different.
- `-WorkstationsOnly` — WMI filter `ProductType = 1`. Servers and domain controllers are left out. The request was every Windows device, so this is off unless you pass it.
- `-Enforce:$false` — link the GPO but do not enforce it.
- `-TargetDn "OU=Pilot,DC=er-contech,DC=local"` — link somewhere other than the domain root.

## When it reaches a PC

Startup scripts run at startup, not during a background refresh. After the GPO
replicates, each computer installs the fonts at its next restart. Each person
gets the asset folder at their next sign-in.

On one pilot machine:

```
gpupdate /force
```

Restart, sign in, then:

```
\\<dns>\SYSVOL\<dns>\ErCon-Rebrand\Verify-ErConRebrand.ps1
```

Logs, if you need them:

- `C:\ProgramData\Er-Con\rebrand-fonts.log`
- `%LOCALAPPDATA%\Er-Con\rebrand-assets.log`

## Confirm it worked

1. Open `Er-Con Template.potx` from Documents\Er-Con Rebrand Assets. It should not offer to repair the file.
2. The font menu shows Archivo, Source Sans 3 and IBM Plex Mono, one entry each, with Regular, Italic, Bold and Bold Italic. Archivo SemiBold as its own entry means an extra file was installed.
3. Design > Colors shows the Er-Con set. Signal ramp 1-4 is blue.
4. Save a test .docx and open it on a machine without these fonts. The text should still render in Archivo and Source Sans 3. Embedding is already set in `Er-Con Template.potx` and `Er-Con Letterhead.dotx`. Nothing in this GPO changes that.
5. Arial is still in the font menu.

## What this does not cover

- Macs. The request's Jamf / Intune-for-macOS path is separate.
- Windows devices that are not joined to the er-contech Active Directory domain. Entra-only PCs do not process this GPO.
- Word for Mac font embedding on perpetual Office 2021. Microsoft documents that as Microsoft 365 only. PowerPoint for Mac lists 365, 2024 and 2021. Flag any author on a perpetual licence. Staff guidance is still to send PDFs for anything final.

## Taking it back

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Unlink-ErConRebrandGpo.ps1 -ConfirmDomainWide er-contech
```

That disables the link. Fonts already on a PC stay there. To remove the twelve
faces from one PC, run `payload\Remove-ErConFonts.ps1` as admin on that PC. It
deletes a file only when the hash still matches this kit, and it will not touch
Arial. `-DeleteGpo` and `-DeleteSysvolPayload` are separate, explicit switches.
