#Requires -Version 5.1
<#
.SYNOPSIS
    FocusBlocker - interaktywne menu w terminalu.
    Uruchom skrótem "FocusBlocker" z menu Start albo:
        powershell -ExecutionPolicy Bypass -File "C:\ProgramData\FocusBlocker\focus.ps1"
#>
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"

# Zapis pliku hosts wymaga uprawnień administratora - poproś o nie w razie potrzeby
if (-not (Test-FBAdmin)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

try { $Host.UI.RawUI.WindowTitle = 'FocusBlocker' } catch { }

# ------------------------------------------------------------------ pomocnicze UI

function Clear-Screen { if (-not $FB_NoClear) { Clear-Host } }

function Write-Line([string]$Text = '', [string]$Color) {
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
}

function Read-Line([string]$Prompt) {
    $v = Read-Host "  $Prompt"
    if ($null -eq $v) { return '' }
    return $v.Trim()
}

function Confirm-Choice([string]$Question) {
    $a = Read-Line "$Question [t/N]"
    return ($a -match '^(t|tak|y|yes)$')
}

function Wait-Enter { [void](Read-Line 'Enter - powrót') }

function Write-Err([string]$Text) { Write-Line "  ✖ $Text" Yellow }
function Write-Ok([string]$Text)  { Write-Line "  ✔ $Text" Green }

function Test-PageServer {
    try {
        $null = Invoke-RestMethod -Uri "http://127.0.0.1:$FB_Port/status" -TimeoutSec 2
        return $true
    } catch { return $false }
}

function Show-Header {
    $st = Invoke-FBAuto   # przy okazji synchronizuje plik hosts
    $now = Get-FBNow
    Clear-Screen
    Write-Line ''
    Write-Line '  FocusBlocker' Cyan
    Write-Line ('  ' + ('─' * 50)) DarkGray
    if ($st.Active) {
        Write-Host '  ● BLOKADA AKTYWNA' -ForegroundColor Red -NoNewline
        Write-Host ("   do {0}  (zostało {1})" -f (Format-FBWhen $st.Until), (Format-FBDuration ($st.Until - $now)))
        Write-Line "    powód: $($st.Reason)" DarkGray
    } else {
        Write-Host '  ○ Brak blokady' -ForegroundColor Green -NoNewline
        if ($st.NextStart) { Write-Host ("   następna: {0}" -f (Format-FBWhen $st.NextStart)) } else { Write-Host '' }
    }
    $page = if (Test-PageServer) { 'działa' } else { 'nie odpowiada' }
    Write-Line ("    stron na liście: {0} · przedziałów: {1} · strona blokady: {2}" -f @(Get-FBListEntries).Count, @($st.Config.Schedule).Count, $page) DarkGray
    Write-Line ('  ' + ('─' * 50)) DarkGray
    return $st
}

# ------------------------------------------------------------------ 1. blokada ręczna

function Menu-Block {
    $st = Show-Header
    $title = if ($st.Active) { 'Przedłuż blokadę' } else { 'Włącz blokadę teraz' }
    Write-Line ''
    Write-Line "  $title - na jak długo?" White
    Write-Line '   1  25 min'
    Write-Line '   2  50 min'
    Write-Line '   3  1,5 h'
    Write-Line '   4  2 h'
    Write-Line '   5  do końca dnia'
    Write-Line '   6  inny czas (liczba minut albo godzina, np. 90 lub 16:30)'
    Write-Line '   Enter  powrót' DarkGray
    $c = Read-Line '>'
    $now = Get-FBNow
    $until = $null
    switch ($c) {
        '1' { $until = $now.AddMinutes(25) }
        '2' { $until = $now.AddMinutes(50) }
        '3' { $until = $now.AddMinutes(90) }
        '4' { $until = $now.AddMinutes(120) }
        '5' { $until = $now.Date.AddDays(1).AddMinutes(-1) }
        '6' {
            $v = Read-Line 'Minuty albo godzina końca'
            if ($v -match '^\d{1,2}[:.]\d{2}$') {
                try { $until = $now.Date + (ConvertTo-FBTime $v) } catch { Write-Err $_.Exception.Message; Wait-Enter; return }
                if ($until -le $now) { $until = $until.AddDays(1) }
            } elseif ($v -match '^\d+$' -and [int]$v -gt 0) {
                $until = $now.AddMinutes([int]$v)
            } else { Write-Err 'Nie rozumiem tej wartości.'; Wait-Enter; return }
        }
        default { return }
    }
    $max = $now.AddDays(7)
    if ($until -gt $max) { Write-Err 'Maksymalnie 7 dni naraz.'; Wait-Enter; return }
    if ($st.Active -and $until -le $st.Until) {
        Write-Err "Blokada i tak trwa dłużej - do $(Format-FBWhen $st.Until)."
        Wait-Enter; return
    }
    Write-Line ''
    Write-Line ("  Blokada potrwa do {0} ({1})." -f (Format-FBWhen $until), (Format-FBDuration ($until - $now))) White
    Write-Line '  Nie będzie można jej przerwać ani skrócić.' Yellow
    if (Confirm-Choice 'Włączyć?') {
        $u = Start-FBManualBlock $until
        Write-Ok "Blokada aktywna do $(Format-FBWhen $u). Powodzenia!"
        Wait-Enter
    }
}

# ------------------------------------------------------------------ 2. lista stron

function Menu-List {
    while ($true) {
        $st = Show-Header
        $list = @(Get-FBListEntries)
        Write-Line ''
        Write-Line '  Lista blokowanych stron' White
        Write-Line '  (do każdej domeny głównej dochodzi automatycznie www. i m.)' DarkGray
        if ($list.Count -eq 0) { Write-Line '   (pusta)' DarkGray }
        for ($i = 0; $i -lt $list.Count; $i++) { Write-Line ('  {0,3}. {1}' -f ($i + 1), $list[$i]) }
        Write-Line ''
        Write-Line '   d  dodaj'
        if ($st.Active) { Write-Line '   u  usuń  (niedostępne podczas blokady)' DarkGray } else { Write-Line '   u  usuń' }
        Write-Line '   Enter  powrót' DarkGray
        switch (Read-Line '>') {
            'd' {
                $v = Read-Line 'Domena (kilka - po przecinku, np. wykop.pl, onet.pl)'
                foreach ($part in ($v -split '[,;\s]+' | Where-Object { $_ })) {
                    try {
                        if (Add-FBDomain $part) { Write-Ok "Dodano: $(ConvertTo-FBDomain $part)" }
                        else { Write-Err "Już jest na liście: $part" }
                    } catch { Write-Err $_.Exception.Message }
                }
                [void](Invoke-FBAuto)
                Wait-Enter
            }
            'u' {
                if ((Get-FBStatus).Active) { Write-Err 'Blokada trwa - usuwanie stron jest zablokowane.'; Wait-Enter; continue }
                $n = Read-Line 'Numer strony do usunięcia'
                if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $list.Count) {
                    try { Remove-FBDomain $list[[int]$n - 1]; Write-Ok "Usunięto: $($list[[int]$n - 1])" } catch { Write-Err $_.Exception.Message }
                } else { Write-Err 'Nie ma takiego numeru.' }
                Wait-Enter
            }
            default { return }
        }
    }
}

# ------------------------------------------------------------------ 3. harmonogram

function Menu-Schedule {
    while ($true) {
        $st = Show-Header
        $cfg = Get-FBConfig
        $entries = @($cfg.Schedule)
        Write-Line ''
        Write-Line '  Harmonogram (w tych godzinach blokada włącza się sama)' White
        if ($entries.Count -eq 0) { Write-Line '   (pusty)' DarkGray }
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $e = $entries[$i]
            Write-Line ('  {0,3}. {1,-22} {2}–{3}' -f ($i + 1), (Format-FBDays $e.Days), $e.From, $e.To)
        }
        Write-Line ''
        Write-Line '   d  dodaj przedział'
        if ($st.Active) { Write-Line '   u  usuń przedział  (niedostępne podczas blokady)' DarkGray } else { Write-Line '   u  usuń przedział' }
        Write-Line '   Enter  powrót' DarkGray
        switch (Read-Line '>') {
            'd' {
                try {
                    $days = ConvertFrom-FBDaysInput (Read-Line 'Dni (np. pon-pt, sob nd, codziennie)')
                    $from = Read-Line 'Od (HH:mm)'; [void](ConvertTo-FBTime $from)
                    $to   = Read-Line 'Do (HH:mm)'; [void](ConvertTo-FBTime $to)
                    if ((ConvertTo-FBTime $from) -eq (ConvertTo-FBTime $to)) { throw 'Godzina początku i końca są takie same.' }
                } catch { Write-Err $_.Exception.Message; Wait-Enter; continue }
                $new = [pscustomobject]@{ Days = $days; From = (ConvertTo-FBTime $from).ToString('hh\:mm'); To = (ConvertTo-FBTime $to).ToString('hh\:mm') }
                if ($new.To -eq '1.00:00' -or $to -match '^\s*24:00') { $new.To = '24:00' }
                $test = @(Get-FBIntervals ([pscustomobject]@{ Schedule = @($new) }))
                if (Get-FBIntervalEndAt $test (Get-FBNow)) {
                    Write-Line '  Ten przedział obejmuje bieżącą chwilę - blokada zacznie się od razu i nie da się jej przerwać.' Yellow
                    if (-not (Confirm-Choice 'Dodać mimo to?')) { continue }
                }
                $cfg.Schedule = @($entries) + $new
                Save-FBConfig $cfg
                Write-FBLog ("Dodano przedział: {0} {1}-{2}" -f (Format-FBDays $new.Days), $new.From, $new.To)
                [void](Invoke-FBAuto)
                Write-Ok ("Dodano: {0} {1}–{2}" -f (Format-FBDays $new.Days), $new.From, $new.To)
                Wait-Enter
            }
            'u' {
                if ((Get-FBStatus).Active) { Write-Err 'Blokada trwa - usuwanie przedziałów jest zablokowane.'; Wait-Enter; continue }
                $n = Read-Line 'Numer przedziału do usunięcia'
                if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $entries.Count) {
                    $gone = $entries[[int]$n - 1]
                    $cfg.Schedule = @(for ($i = 0; $i -lt $entries.Count; $i++) { if ($i -ne [int]$n - 1) { $entries[$i] } })
                    Save-FBConfig $cfg
                    Write-FBLog ("Usunięto przedział: {0} {1}-{2}" -f (Format-FBDays $gone.Days), $gone.From, $gone.To)
                    Write-Ok 'Usunięto.'
                } else { Write-Err 'Nie ma takiego numeru.' }
                Wait-Enter
            }
            default { return }
        }
    }
}

# ------------------------------------------------------------------ 4. tekst strony blokady

function Menu-Message {
    [void](Show-Header)
    $cfg = Get-FBConfig
    Write-Line ''
    Write-Line '  Tekst na stronie blokady' White
    Write-Line "  Teraz: $($cfg.Message)" Gray
    Write-Line ''
    Write-Line '  Wpisz nowy tekst. Enter - bez zmian, "-" - przywróć domyślny.' DarkGray
    $v = Read-Line 'Nowy tekst'
    if (-not $v) { return }
    $cfg.Message = if ($v -eq '-') { $FB_DefaultMessage } else { $v }
    Save-FBConfig $cfg
    Write-Ok 'Zapisano. Zobaczysz go przy następnej próbie wejścia na zablokowaną stronę.'
    Wait-Enter
}

# ------------------------------------------------------------------ 5. dziennik

function Menu-Log {
    [void](Show-Header)
    Write-Line ''
    Write-Line '  Ostatnie wpisy w dzienniku' White
    if (Test-Path $FB_LogPath) {
        Get-Content $FB_LogPath -Tail 25 -Encoding UTF8 | ForEach-Object { Write-Line "  $_" Gray }
    } else { Write-Line '   (brak wpisów)' DarkGray }
    Write-Line ''
    Wait-Enter
}

# ------------------------------------------------------------------ menu główne

while ($true) {
    try {
        $st = Show-Header
        Write-Line ''
        if ($st.Active) { Write-Line '   1  Przedłuż blokadę' } else { Write-Line '   1  Włącz blokadę teraz' }
        Write-Line '   2  Lista stron'
        Write-Line '   3  Harmonogram'
        Write-Line '   4  Tekst na stronie blokady'
        Write-Line '   5  Dziennik'
        Write-Line '   0  Wyjście'
        switch (Read-Line '>') {
            '1' { Menu-Block }
            '2' { Menu-List }
            '3' { Menu-Schedule }
            '4' { Menu-Message }
            '5' { Menu-Log }
            '0' { exit 0 }
            'q' { exit 0 }
        }
    } catch {
        Write-Err $_.Exception.Message
        Wait-Enter
    }
}
