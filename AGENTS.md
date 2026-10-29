# Agent instructions

This repository is the Er-Con rebrand kit for the er-contech Active Directory domain. It installs fonts and publishes logos, templates, and instructions to Authenticated Users. It is not a web application. Do not add a frontend, a package.json, or a new framework.

Read [README.md](README.md) for the map and [ADMIN-INSTALLATION.md](ADMIN-INSTALLATION.md) for the operator procedure. If you change behavior an administrator would notice, update ADMIN-INSTALLATION.md in the same change. Those two documents must not disagree.

## Hard rules

1. Domain guard stays. `Deploy-ErConRebrandGpo.ps1` and `Unlink-ErConRebrandGpo.ps1` and `New-ErConAssetShare.ps1` require `-ConfirmDomainWide er-contech` and refuse any other DNS and NetBIOS pair. Do not widen the check. Do not default the parameter.
2. Exactly twelve static TrueType files, the ones already under `payload/Assets/Fonts to install/`. No variable fonts (no `fvar` table). No Archivo SemiBold, no ExtraBold, no Light, no other family.
3. Never unregister or delete Arial, Calibri, or any font whose SHA-256 is not in `payload/fonts.manifest.json`. `Remove-ErConFonts.ps1` may delete a file only after the hash matches.
4. Registry value name is the OpenType name ID 4 (full name) plus ` (TrueType)`. Example: `Archivo Regular (TrueType)`. Do not use name ID 1, name ID 16, or the file name as the registry value name.
5. Staff files land in `%USERPROFILE%\Documents\Er-Con Rebrand Assets`. Not the profile root. Not Desktop. `Copy-ErConAssets.ps1` excludes `Fonts to install`.
6. The server share is the folder `D:\Er-Con Rebrand Assets` and the share name `Er-Con Rebrand Assets`. Authenticated Users get Read on the share and Read & execute on NTFS. Do not grant Everyone, Users, or Authenticated Users Change or Full. Domain Admins and Administrators stay Full. SYSTEM stays Full. Inheritance on that folder stays off.
7. GPO display name stays `Er-Con Rebrand - Fonts and Assets`. Do not create a second GPO for the same job.
8. Computer startup installs fonts as SYSTEM from SYSVOL. User logon copies assets. Do not swap those. Do not install fonts into a user profile.
9. Leave these registry values in the GPO: `SyncForegroundPolicy` = 1, `RunStartupScriptSync` = 1, `EnableLogonScriptDelay` = 0. Without them the scripts run before SYSVOL is reachable.
10. Authenticated Users keeps GpoRead and GpoApply. Do not remove Authenticated Users from Delegation. On current Windows that stops the GPO from applying.
11. Do not edit font embedding inside the `.potx` or `.dotx`. It is already set.
12. Scripts target Windows PowerShell 5.1 (`powershell.exe`). Do not switch the documented commands to `pwsh`.
13. `psscripts.ini` is UTF-16 LE. The deploy script writes it that way. Do not “fix” the encoding.
14. Macs and Entra-only devices are out of scope. Do not add a branch for them in these scripts.
15. `Copy-ErConAssets.ps1` uses `robocopy /MIR` into an IT-owned Documents folder. Do not point `/MIR` at a broader path.
16. Operators must run from the kit root. The most common failure is invoking `.\Deploy-ErConRebrandGpo.ps1` from `C:\Windows\system32` or another folder that does not contain the script. Docs must keep a prominent “change directory first” instruction and the exact error message. When improving error handling, prefer a message that prints the current directory and `$PSScriptRoot`.

## Where behavior lives

| Change | File |
| --- | --- |
| Who gets the GPO, link, enforce, WMI, script CSE | `Deploy-ErConRebrandGpo.ps1` |
| Share path, share ACL, NTFS ACL | `New-ErConAssetShare.ps1` |
| Which fonts are copied and how they are registered | `payload/Install-ErConFonts.ps1` and `payload/fonts.manifest.json` |
| What lands in Documents | `payload/Copy-ErConAssets.ps1` |
| What “it worked” checks | `payload/Verify-ErConRebrand.ps1` and ADMIN-INSTALLATION.md step 9 |
| Uninstall | `payload/Remove-ErConFonts.ps1` |
| Disable the link | `Unlink-ErConRebrandGpo.ps1` |

The files under `\\<dns>\SYSVOL\<dns>\ErCon-Rebrand` are a copy. Edit this repository. Deploy copies `payload\` over SYSVOL with `robocopy /MIR`.

The GPO’s startup and logon entries are stubs named `Launch-Install-ErConFonts.ps1` and `Launch-Copy-ErConAssets.ps1`. Deploy writes them. Do not add a second script entry in GPMC. A second entry runs the install twice.

## Font manifest

`payload/fonts.manifest.json` is the allow-list. Each object has `file`, `relativePath` (forward slashes, relative to `payload\`), `family`, `fullName` (name ID 4, English, platform 3 encoding 1 language 0x409), and lowercase `sha256`.

After any `.ttf` change, regenerate the manifest from this folder and commit it. Do not hand-edit a hash. The generator in `scripts/check-kit.py` can reprint the manifest:

```bash
python3 scripts/check-kit.py --write-manifest
python3 scripts/check-kit.py
```

`Install-ErConFonts.ps1` skips a file on hash mismatch and logs it. A skipped file looks like a successful deploy that did nothing. The check script is how you catch that before the domain sees it.

## Check before you finish

From the repository root:

```bash
python3 scripts/check-kit.py
```

That does not need a domain. It fails if the font count is not 12, a font has an `fvar` table, a hash does not match the manifest, SemiBold is present, a required asset is missing, or the deploy and copy scripts no longer contain the domain guard, the Documents path, or the D: share.

On a domain computer the human test is still required. ADMIN-INSTALLATION.md step 9 is the list. Do not claim the rollout worked because the check script passed.

## Style

Match the scripts that are already here. Windows PowerShell 5.1, `#Requires` at the top, `LiteralPath`, explicit errors, no aliases in new code. Comments explain a constraint a later edit would otherwise violate, not the next line. Do not reformat a file you are not changing.

Operator-facing text is for Seabed IT. Short sentences. Real paths. No filler. Prefer concrete error messages and exact PowerShell commands over general advice.
