#Requires -Version 5.1
<#
.SYNOPSIS
    Instaluje (lub aktualizuje) FocusBlocker.

    * kopiuje pliki do C:\ProgramData\FocusBlocker (zapis tylko dla administratora)
    * zadanie "FocusBlocker"      - co minutę i przy starcie pilnuje blokady
    * zadanie "FocusBlocker-Page" - przy starcie uruchamia serwer strony blokady
    * skrót "FocusBlocker" w menu Start (otwiera menu w terminalu)

    Przy aktualizacji Twoja lista stron i harmonogram zostają bez zmian.
    W trakcie aktywnej blokady instalacja/aktualizacja jest niemożliwa.
#>
$ErrorActionPreference = 'Stop'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Uruchom PowerShell jako administrator.' -ForegroundColor Yellow
    exit 1
}

$src  = $PSScriptRoot
$dest = Join-Path $env:ProgramData 'FocusBlocker'

# Aktualizacja w trakcie blokady mogłaby posłużyć do jej obejścia
if (Test-Path (Join-Path $dest 'lib.ps1')) {
    $FB_Dir = $dest
    . (Join-Path $dest 'lib.ps1')
    $st = Get-FBStatus
    if ($st.Active) {
        Write-Host "Blokada trwa do $(Format-FBWhen $st.Until). Aktualizacja bedzie mozliwa po jej zakonczeniu." -ForegroundColor Yellow
        exit 2
    }
    Remove-Variable FB_Dir
}

# 1. Folder - zapis tylko dla SYSTEM i Administratorów
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
& icacls.exe $dest /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null

# Zatrzymaj stary serwer przed podmianą plików
Stop-ScheduledTask -TaskName 'FocusBlocker-Page' -ErrorAction SilentlyContinue

# 2. Pliki programu (zawsze) i konfiguracja (tylko przy pierwszej instalacji)
foreach ($f in 'lib.ps1', 'blocker.ps1', 'focus.ps1', 'server.ps1', 'uninstall.ps1', 'README.md') {
    Copy-Item (Join-Path $src $f) (Join-Path $dest $f) -Force
}
foreach ($f in 'blocklist.txt', 'config.json') {
    if (-not (Test-Path (Join-Path $dest $f))) { Copy-Item (Join-Path $src $f) (Join-Path $dest $f) }
}
$extDest = Join-Path $dest 'extension'
if (-not (Test-Path $extDest)) { New-Item -ItemType Directory -Path $extDest | Out-Null }
Copy-Item (Join-Path $src 'extension\*') $extDest -Recurse -Force
Get-ChildItem $dest -File -Recurse | Unblock-File -ErrorAction SilentlyContinue

# 3. Kontrola konfiguracji
$FB_Dir = $dest
. (Join-Path $dest 'lib.ps1')
[void](Get-FBStatus)

# 4. Zadania w Harmonogramie zadań
$ps = 'powershell.exe'
$common = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File'
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

$action = New-ScheduledTaskAction -Execute $ps -Argument "$common `"$dest\blocker.ps1`" -Mode Auto"
$everyMinute = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 1)
$atStartup = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
Register-ScheduledTask -TaskName 'FocusBlocker' -Action $action -Trigger $everyMinute, $atStartup `
    -Principal $principal -Settings $settings -Force `
    -Description 'Blokuje rozpraszajace strony (plik hosts) wg harmonogramu. Pliki: C:\ProgramData\FocusBlocker' | Out-Null

$action2 = New-ScheduledTaskAction -Execute $ps -Argument "$common `"$dest\server.ps1`""
$settings2 = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName 'FocusBlocker-Page' -Action $action2 -Trigger (New-ScheduledTaskTrigger -AtStartup) `
    -Principal $principal -Settings $settings2 -Force `
    -Description 'Lokalna strona z komunikatem FocusBlocker (http://127.0.0.1:47615)' | Out-Null
Start-ScheduledTask -TaskName 'FocusBlocker-Page'

# 5. Skrót w menu Start
$lnk = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\FocusBlocker.lnk'
$sh = New-Object -ComObject WScript.Shell
$s = $sh.CreateShortcut($lnk)
$s.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$s.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$dest\focus.ps1`""
$s.WorkingDirectory = $dest
$s.Description = 'FocusBlocker - blokada rozpraszajacych stron'
$s.Save()

# 6. Pierwsza synchronizacja
[void](Invoke-FBAuto)

Write-Host ''
Write-Host "FocusBlocker zainstalowany w $dest" -ForegroundColor Green
Write-Host ''
Write-Host 'Ostatni krok - rozszerzenie z ladna strona blokady (Chrome lub Edge):'
Write-Host '  1. Otworz chrome://extensions (w Edge: edge://extensions)'
Write-Host '  2. Wlacz "Tryb dewelopera"'
Write-Host '  3. "Zaladuj rozpakowane" i wskaz folder:'
Write-Host "     $extDest" -ForegroundColor Cyan
Write-Host ''
Write-Host 'Menu otworzysz skrotem "FocusBlocker" w menu Start.'
