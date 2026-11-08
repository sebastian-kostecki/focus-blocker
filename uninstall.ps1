#Requires -Version 5.1
<#
.SYNOPSIS
    Usuwa FocusBlocker: zadania, sekcję w pliku hosts, skrót i folder programu.
    W trakcie aktywnej blokady odinstalowanie jest niemożliwe.
#>
$ErrorActionPreference = 'Stop'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Uruchom PowerShell jako administrator.' -ForegroundColor Yellow
    exit 1
}

$dest = Join-Path $env:ProgramData 'FocusBlocker'
$lib = Join-Path $dest 'lib.ps1'

if (Test-Path $lib) {
    $FB_Dir = $dest
    . $lib
    $st = Get-FBStatus
    if ($st.Active) {
        Write-Host "Blokada trwa do $(Format-FBWhen $st.Until). Odinstalowanie bedzie mozliwe po jej zakonczeniu." -ForegroundColor Yellow
        exit 2
    }
}

Stop-ScheduledTask -TaskName 'FocusBlocker-Page' -ErrorAction SilentlyContinue
foreach ($t in 'FocusBlocker', 'FocusBlocker-Page') {
    Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
}

if (Test-Path $lib) { Set-FBHostsBlocked $false 'odinstalowanie' }

Remove-Item (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\FocusBlocker.lnk') -ErrorAction SilentlyContinue

Set-Location $env:TEMP
Start-Sleep -Seconds 1
Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue

Write-Host 'FocusBlocker odinstalowany.' -ForegroundColor Green
Write-Host 'Rozszerzenie usun recznie w chrome://extensions (lub edge://extensions).'
