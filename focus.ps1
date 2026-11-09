#Requires -Version 5.1
<#
.SYNOPSIS
    FocusBlocker - interactive terminal menu / interaktywne menu w terminalu.
    Run it with the "FocusBlocker" Start menu shortcut or:
        powershell -ExecutionPolicy Bypass -File "C:\ProgramData\FocusBlocker\focus.ps1"
#>
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"
Update-FBLanguage $null

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

# Tak / yes w obu językach, niezależnie od wybranego
function Confirm-Choice([string]$Question) {
    $a = Read-Line "$Question $(T 'menu.yesNo')"
    return ($a -match '^(t|tak|y|yes)$')
}

function Wait-Enter { [void](Read-Line (T 'menu.back')) }

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
        Write-Host (T 'menu.active') -ForegroundColor Red -NoNewline
        Write-Host (T 'menu.activeUntil' (Format-FBWhen $st.Until) (Format-FBDuration ($st.Until - $now)))
        Write-Line (T 'menu.reason' (Format-FBReason $st.Reason)) DarkGray
    } else {
        Write-Host (T 'menu.inactive') -ForegroundColor Green -NoNewline
        if ($st.NextStart) { Write-Host (T 'menu.next' (Format-FBWhen $st.NextStart)) } else { Write-Host '' }
    }
    $page = if (Test-PageServer) { T 'menu.pageOk' } else { T 'menu.pageDown' }
    Write-Line (T 'menu.summary' @(Get-FBListEntries).Count @($st.Config.Schedule).Count $page) DarkGray
    Write-Line ('  ' + ('─' * 50)) DarkGray
    return $st
}

# ------------------------------------------------------------------ 1. blokada ręczna

function Menu-Block {
    $st = Show-Header
    $title = if ($st.Active) { T 'menu.extend' } else { T 'menu.start' }
    Write-Line ''
    Write-Line "  $(T 'block.howLong' $title)" White
    Write-Line '   1  25 min'
    Write-Line '   2  50 min'
    Write-Line "   3  $(T 'block.90min')"
    Write-Line '   4  2 h'
    Write-Line "   5  $(T 'block.endOfDay')"
    Write-Line "   6  $(T 'block.custom')"
    Write-Line (T 'menu.backItem') DarkGray
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
            $v = Read-Line (T 'block.ask')
            if ($v -match '^\d{1,2}[:.]\d{2}$') {
                try { $until = $now.Date + (ConvertTo-FBTime $v) } catch { Write-Err $_.Exception.Message; Wait-Enter; return }
                if ($until -le $now) { $until = $until.AddDays(1) }
            } elseif ($v -match '^\d+$' -and [int]$v -gt 0) {
                $until = $now.AddMinutes([int]$v)
            } else { Write-Err (T 'block.badValue'); Wait-Enter; return }
        }
        default { return }
    }
    $max = $now.AddDays(7)
    if ($until -gt $max) { Write-Err (T 'block.max'); Wait-Enter; return }
    if ($st.Active -and $until -le $st.Until) {
        Write-Err (T 'block.longer' (Format-FBWhen $st.Until))
        Wait-Enter; return
    }
    Write-Line ''
    Write-Line (T 'block.summary' (Format-FBWhen $until) (Format-FBDuration ($until - $now))) White
    Write-Line (T 'block.warn') Yellow
    if (Confirm-Choice (T 'block.confirm')) {
        $u = Start-FBManualBlock $until
        Write-Ok (T 'block.done' (Format-FBWhen $u))
        Wait-Enter
    }
}

# ------------------------------------------------------------------ 2. lista stron

function Menu-List {
    while ($true) {
        $st = Show-Header
        $list = @(Get-FBListEntries)
        Write-Line ''
        Write-Line (T 'list.title') White
        Write-Line (T 'list.hint') DarkGray
        if ($list.Count -eq 0) { Write-Line (T 'list.empty') DarkGray }
        for ($i = 0; $i -lt $list.Count; $i++) { Write-Line ('  {0,3}. {1}' -f ($i + 1), $list[$i]) }
        Write-Line ''
        Write-Line (T 'list.addItem')
        if ($st.Active) { Write-Line (T 'list.removeLocked') DarkGray } else { Write-Line (T 'list.removeItem') }
        Write-Line (T 'menu.backItem') DarkGray
        # d/a = dodaj/add, u/r = usuń/remove - oba skróty działają w każdym języku
        switch -Regex (Read-Line '>') {
            '^(d|a)$' {
                $v = Read-Line (T 'list.ask')
                foreach ($part in ($v -split '[,;\s]+' | Where-Object { $_ })) {
                    try {
                        if (Add-FBDomain $part) { Write-Ok (T 'list.added' (ConvertTo-FBDomain $part)) }
                        else { Write-Err (T 'list.exists' $part) }
                    } catch { Write-Err $_.Exception.Message }
                }
                [void](Invoke-FBAuto)
                Wait-Enter
            }
            '^(u|r)$' {
                if ((Get-FBStatus).Active) { Write-Err (T 'list.locked'); Wait-Enter; continue }
                $n = Read-Line (T 'list.askNumber')
                if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $list.Count) {
                    try { Remove-FBDomain $list[[int]$n - 1]; Write-Ok (T 'list.removed' $list[[int]$n - 1]) } catch { Write-Err $_.Exception.Message }
                } else { Write-Err (T 'menu.noSuchNumber') }
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
        Write-Line (T 'sched.title') White
        if ($entries.Count -eq 0) { Write-Line (T 'sched.empty') DarkGray }
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $e = $entries[$i]
            Write-Line ('  {0,3}. {1,-22} {2}–{3}' -f ($i + 1), (Format-FBDays $e.Days), $e.From, $e.To)
        }
        Write-Line ''
        Write-Line (T 'sched.addItem')
        if ($st.Active) { Write-Line (T 'sched.removeLocked') DarkGray } else { Write-Line (T 'sched.removeItem') }
        Write-Line (T 'menu.backItem') DarkGray
        switch -Regex (Read-Line '>') {
            '^(d|a)$' {
                try {
                    $days = ConvertFrom-FBDaysInput (Read-Line (T 'sched.askDays'))
                    $from = Read-Line (T 'sched.askFrom'); [void](ConvertTo-FBTime $from)
                    $to   = Read-Line (T 'sched.askTo');   [void](ConvertTo-FBTime $to)
                    if ((ConvertTo-FBTime $from) -eq (ConvertTo-FBTime $to)) { throw (T 'sched.same') }
                } catch { Write-Err $_.Exception.Message; Wait-Enter; continue }
                $new = [pscustomobject]@{ Days = $days; From = (ConvertTo-FBTime $from).ToString('hh\:mm'); To = (ConvertTo-FBTime $to).ToString('hh\:mm') }
                if ($new.To -eq '1.00:00' -or $to -match '^\s*24:00') { $new.To = '24:00' }
                $test = @(Get-FBIntervals ([pscustomobject]@{ Schedule = @($new) }))
                if (Get-FBIntervalEndAt $test (Get-FBNow)) {
                    Write-Line (T 'sched.nowWarn') Yellow
                    if (-not (Confirm-Choice (T 'sched.confirm'))) { continue }
                }
                $cfg.Schedule = @($entries) + $new
                Save-FBConfig $cfg
                Write-FBLog (T 'log.rangeAdded' (Format-FBDays $new.Days) $new.From $new.To)
                [void](Invoke-FBAuto)
                Write-Ok (T 'sched.added' (Format-FBDays $new.Days) $new.From $new.To)
                Wait-Enter
            }
            '^(u|r)$' {
                if ((Get-FBStatus).Active) { Write-Err (T 'sched.locked'); Wait-Enter; continue }
                $n = Read-Line (T 'sched.askNumber')
                if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $entries.Count) {
                    $gone = $entries[[int]$n - 1]
                    $cfg.Schedule = @(for ($i = 0; $i -lt $entries.Count; $i++) { if ($i -ne [int]$n - 1) { $entries[$i] } })
                    Save-FBConfig $cfg
                    Write-FBLog (T 'log.rangeRemoved' (Format-FBDays $gone.Days) $gone.From $gone.To)
                    Write-Ok (T 'menu.removed')
                } else { Write-Err (T 'menu.noSuchNumber') }
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
    Write-Line (T 'msg.title') White
    Write-Line (T 'msg.current' $cfg.Message) Gray
    Write-Line ''
    Write-Line (T 'msg.hint') DarkGray
    $v = Read-Line (T 'msg.ask')
    if (-not $v) { return }
    $cfg.Message = if ($v -eq '-') { T 'default.message' } else { $v }
    Save-FBConfig $cfg
    Write-Ok (T 'msg.saved')
    Wait-Enter
}

# ------------------------------------------------------------------ 5. dziennik

function Menu-Log {
    [void](Show-Header)
    Write-Line ''
    Write-Line (T 'log.title') White
    if (Test-Path $FB_LogPath) {
        Get-Content $FB_LogPath -Tail 25 -Encoding UTF8 | ForEach-Object { Write-Line "  $_" Gray }
    } else { Write-Line (T 'log.empty') DarkGray }
    Write-Line ''
    Wait-Enter
}

# ------------------------------------------------------------------ 6. język

function Menu-Language {
    [void](Show-Header)
    Write-Line ''
    Write-Line '  Język / Language' White
    $codes = @($FB_Languages.Keys)
    for ($i = 0; $i -lt $codes.Count; $i++) { Write-Line ('   {0}  {1}' -f ($i + 1), $FB_Languages[$codes[$i]]) }
    Write-Line (T 'menu.backItem') DarkGray
    $n = Read-Line '>'
    if ($n -notmatch '^\d+$' -or [int]$n -lt 1 -or [int]$n -gt $codes.Count) { return }
    $cfg = Get-FBConfig
    $cfg.Language = $codes[[int]$n - 1]
    Save-FBConfig $cfg
    Update-FBLanguage $null
    Write-FBLog (T 'log.language' $FB_Languages[$FB_State.Lang])
    Write-Ok (T 'lang.saved' $FB_Languages[$FB_State.Lang])
    Wait-Enter
}

# ------------------------------------------------------------------ menu główne

while ($true) {
    try {
        $st = Show-Header
        Write-Line ''
        if ($st.Active) { Write-Line "   1  $(T 'menu.extend')" } else { Write-Line "   1  $(T 'menu.start')" }
        Write-Line "   2  $(T 'menu.list')"
        Write-Line "   3  $(T 'menu.schedule')"
        Write-Line "   4  $(T 'menu.message')"
        Write-Line "   5  $(T 'menu.log')"
        Write-Line "   6  $(T 'menu.language')"
        Write-Line "   0  $(T 'menu.exit')"
        switch (Read-Line '>') {
            '1' { Menu-Block }
            '2' { Menu-List }
            '3' { Menu-Schedule }
            '4' { Menu-Message }
            '5' { Menu-Log }
            '6' { Menu-Language }
            '0' { exit 0 }
            'q' { exit 0 }
        }
    } catch {
        Write-Err $_.Exception.Message
        Wait-Enter
    }
}
