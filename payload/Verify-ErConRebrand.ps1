# Run on a PC after reboot and sign-in. Prints PASS/FAIL. Does not change the PC.
#Requires -Version 5.1
$ErrorActionPreference = 'Continue'

$manifestPath = Join-Path $PSScriptRoot 'fonts.manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Output "FAIL  fonts.manifest.json not found next to this script."
    exit 1
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$fontsDir = Join-Path $env:WINDIR 'Fonts'
$reg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$fail = 0

function Report([bool]$Ok, [string]$Message) {
    if ($Ok) { Write-Output "PASS  $Message" }
    else {
        Write-Output "FAIL  $Message"
        $script:fail++
    }
}

foreach ($font in @($manifest.fonts)) {
    $file = Join-Path $fontsDir ([string]$font.file)
    $valueName = "$($font.fullName) (TrueType)"
    $registered = $reg.PSObject.Properties[$valueName].Value
    Report ((Test-Path -LiteralPath $file) -and ($registered -eq $font.file)) "$valueName -> $($font.file)"
}

$arial = $reg.PSObject.Properties['Arial (TrueType)'].Value
Report ([bool]$arial) "Arial is still registered ($(if ($arial) { $arial } else { 'missing' })). This package does not remove it."

$semi = @($reg.PSObject.Properties.Name | Where-Object { $_ -like 'Archivo SemiBold*' })
Report ($semi.Count -eq 0) $(if ($semi.Count -eq 0) {
        'No Archivo SemiBold entry. The menu should show one Archivo family.'
    } else {
        "Archivo SemiBold is registered ($($semi -join ', ')). An extra file was installed. This package does not install it."
    })

$home = Join-Path (Join-Path $env:USERPROFILE 'Documents') 'Er-Con Rebrand Assets'
Report (Test-Path -LiteralPath (Join-Path $home 'READ ME FIRST.md')) "READ ME FIRST.md in $home"
Report (Test-Path -LiteralPath (Join-Path $home 'Templates\Er-Con Template.potx')) 'Er-Con Template.potx is in Documents'
Report (Test-Path -LiteralPath (Join-Path $home 'Templates\Er-Con Letterhead.dotx')) 'Er-Con Letterhead.dotx is in Documents'
Report (Test-Path -LiteralPath (Join-Path $home 'Er-Con Brand Standards.pdf')) 'Brand standards PDF is in Documents'
Report (Test-Path -LiteralPath (Join-Path $home 'Logos')) 'Logos folder is in Documents'
Report (Test-Path -LiteralPath (Join-Path $home 'Office Theme')) 'Office Theme folder is in Documents'

Write-Output ''
Write-Output 'Still check by hand in PowerPoint, from Documents\Er-Con Rebrand Assets:'
Write-Output '  1. Open Templates\Er-Con Template.potx. It should not ask to repair the file.'
Write-Output '  2. Font menu: Archivo, Source Sans 3, IBM Plex Mono. One entry each, four faces.'
Write-Output '  3. Design > Colors shows the Er-Con set. Signal ramp 1-4 is blue.'
Write-Output '  4. Save a test .docx and open it on a PC without the fonts. Archivo and Source Sans 3 should still render.'
Write-Output ''
if ($fail -gt 0) {
    Write-Output "$fail check(s) failed."
    exit 1
}
Write-Output 'Machine checks passed.'
exit 0
