#Requires -Version 5.1
<#
.SYNOPSIS
    FocusBlocker - wersja nieinteraktywna (używa jej zadanie w Harmonogramie zadań).
    Do codziennej obsługi uruchamiaj focus.ps1 (menu).

.PARAMETER Mode
    Auto    doprowadza plik hosts do zgodności z harmonogramem i blokadą ręczną (domyślnie)
    On      włącza blokadę ręczną na -Minutes minut (nie można jej skrócić)
    Status  pokazuje stan

    Trybu "wyłącz" celowo nie ma.
#>
[CmdletBinding()]
param(
    [ValidateSet('Auto', 'On', 'Status')]
    [string]$Mode = 'Auto',
    [int]$Minutes = 60
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"

if ($Mode -ne 'Status' -and -not (Test-FBAdmin)) {
    Write-Error 'Uruchom PowerShell jako administrator.'
    exit 1
}

switch ($Mode) {
    'Auto' { [void](Invoke-FBAuto) }
    'On' {
        if ($Minutes -le 0) { Write-Error 'Podaj -Minutes większe od zera.'; exit 1 }
        $until = Start-FBManualBlock ((Get-FBNow).AddMinutes($Minutes))
        Write-Host "Blokada aktywna do $(Format-FBWhen $until)."
    }
    'Status' {
        $st = Get-FBStatus
        if ($st.Active) { Write-Host "Blokada AKTYWNA ($($st.Reason)) do $(Format-FBWhen $st.Until)" }
        else {
            $next = if ($st.NextStart) { Format-FBWhen $st.NextStart } else { 'brak w harmonogramie' }
            Write-Host "Brak blokady. Następna: $next"
        }
        Write-Host "Plik hosts zablokowany: $(Test-FBHostsBlocked)"
        Write-Host "Domen: $($st.Domains.Count)"
    }
}
