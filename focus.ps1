#Requires -Version 5.1
<#
.SYNOPSIS
    FocusBlocker - interactive terminal dashboard / interaktywny pulpit w terminalu.
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

# Do testów można podstawić kolejkę klawiszy: $FB_KeyQueue = [Collections.Generic.Queue[string]]
if ($null -eq $FB_KeyQueue -and [Console]::IsInputRedirected) {
    Write-Host 'FocusBlocker needs an interactive terminal.'
    exit 1
}

try { $Host.UI.RawUI.WindowTitle = 'FocusBlocker' } catch { }

# ------------------------------------------------------------------ ekran

# Tryb awaryjny dla czcionek bez znaków ramek: FOCUSBLOCKER_ASCII=1
$script:Ascii = [bool]$FB_Ascii -or ($env:FOCUSBLOCKER_ASCII -eq '1')
$script:AsciiMap = @{
    '█' = '#'; '░' = '-'; '─' = '-'; '▸' = '>'; '●' = '*'; '○' = 'o'; '·' = '.'; '▼' = 'v'
    '↑' = '^'; '↓' = 'v'; '✔' = '+'; '✖' = 'x'; '…' = '...'; '–' = '-'; '›' = '>'; '┌' = '+'; '│' = '|'; '└' = '+'
}

function ConvertTo-Display([string]$Text) {
    if (-not $script:Ascii) { return $Text }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        $k = [string]$ch
        if ($script:AsciiMap.ContainsKey($k)) { [void]$sb.Append($script:AsciiMap[$k]) } else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

# Fragment tekstu z kolorem i Linia z fragmentów; ekran to lista linii
function Seg([string]$Text, [string]$Fg = 'Gray', [string]$Bg = '') { , @($Text, $Fg, $Bg) }
function Ln { , $args }

function Get-Width {
    try { return [Math]::Max(44, [Math]::Min(62, $Host.UI.RawUI.WindowSize.Width - 2)) } catch { return 60 }
}

function Set-Cursor([bool]$Visible) { try { [Console]::CursorVisible = $Visible } catch { } }

$script:Prev = 0
$script:Top = 0
function Reset-Screen {
    if (-not $FB_NoClear) {
        Clear-Host
        try { $script:Top = [Console]::CursorTop } catch { $script:Top = 0 }
    }
    $script:Prev = 0
}

# Rysuje od lewego górnego rogu bez czyszczenia ekranu - dzięki temu odliczanie nie miga
function Show-Screen($Lines) {
    $w = Get-Width
    if (-not $FB_NoClear) { try { [Console]::SetCursorPosition(0, $script:Top) } catch { } }
    foreach ($ln in $Lines) {
        if ($FB_NoClear) {   # tryb testowy: cała linia naraz, bez kolorów
            Write-Host (-join @($ln | ForEach-Object { ConvertTo-Display $_[0] }))
            continue
        }
        $len = 0
        foreach ($s in $ln) {
            $txt = ConvertTo-Display $s[0]
            $p = @{ Object = $txt; NoNewline = $true }
            if ($s[1]) { $p.ForegroundColor = $s[1] }
            if ($s[2]) { $p.BackgroundColor = $s[2] }
            Write-Host @p
            $len += $txt.Length
        }
        if (-not $FB_NoClear -and $len -lt $w) { Write-Host (' ' * ($w - $len)) -NoNewline }
        Write-Host ''
    }
    if (-not $FB_NoClear) { for ($i = $Lines.Count; $i -lt $script:Prev; $i++) { Write-Host (' ' * $w) } }
    $script:Prev = $Lines.Count
}

function Move-ToPrompt([int]$Rows) {
    if (-not $FB_NoClear) { try { [Console]::SetCursorPosition(0, $script:Top + $Rows) } catch { } }
}

# ------------------------------------------------------------------ klawiatura

function New-Key([string]$Key, [string]$Char = '') { [pscustomobject]@{ Key = $Key; Char = $Char } }

# Zwraca klawisz albo $null po upływie $TimeoutMs (0 = czekaj bez końca)
function Read-FBKey([int]$TimeoutMs = 0) {
    if ($null -ne $FB_KeyQueue) {
        if ($FB_KeyQueue.Count -eq 0) { return (New-Key 'Eof') }
        $n = $FB_KeyQueue.Dequeue()
        if ($n -eq 'Tick') { return $null }
        if ($n.Length -eq 1) { return (New-Key $n.ToUpperInvariant() $n) }
        return (New-Key $n)
    }
    $deadline = [datetime]::UtcNow.AddMilliseconds($TimeoutMs)
    while ($true) {
        if ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            return (New-Key $k.Key.ToString() ([string]$k.KeyChar))
        }
        if ($TimeoutMs -gt 0 -and [datetime]::UtcNow -ge $deadline) { return $null }
        Start-Sleep -Milliseconds 40
    }
}

# Linia tekstu pod ekranem; Esc anuluje ($null)
function Read-Text([string]$Prompt) {
    Set-Cursor $true
    Write-Host (ConvertTo-Display "  $Prompt ") -NoNewline -ForegroundColor White
    $buf = New-Object System.Text.StringBuilder
    try {
        while ($true) {
            $k = Read-FBKey 0
            switch ($k.Key) {
                'Enter'     { Write-Host ''; return $buf.ToString().Trim() }
                'Escape'    { Write-Host ''; return $null }
                'Eof'       { Write-Host ''; return $null }
                'Backspace' {
                    if ($buf.Length -gt 0) { $buf.Length = $buf.Length - 1; Write-Host "`b `b" -NoNewline }
                }
                default {
                    if ($k.Char.Length -eq 1 -and [int][char]$k.Char -ge 32) {
                        [void]$buf.Append($k.Char)
                        Write-Host $k.Char -NoNewline -ForegroundColor Cyan
                    }
                }
            }
        }
    } finally { Set-Cursor $false }
}

function Move-Selection([int]$Sel, [int]$Count, $Key) {
    if ($Count -le 0) { return 0 }
    switch ($Key.Key) {
        'UpArrow'   { return ($Sel - 1 + $Count) % $Count }
        'DownArrow' { return ($Sel + 1) % $Count }
        'Home'      { return 0 }
        'End'       { return $Count - 1 }
        'PageUp'    { return [Math]::Max(0, $Sel - 5) }
        'PageDown'  { return [Math]::Min($Count - 1, $Sel + 5) }
    }
    return $Sel
}

function Test-Back($Key) { return ($Key.Key -in 'Escape', 'Backspace', 'Eof') }

# ------------------------------------------------------------------ dane

$script:St = $null
$script:StAt = [datetime]::MinValue
$script:Page = [pscustomobject]@{ Up = $false; Tries = $null }
$script:PageAt = [datetime]::MinValue
$script:SiteCount = 0
$script:Flash = $null

function Get-PageInfo {
    try {
        # najpierw szybki test portu - gdy serwer nie działa, nie czekamy na limit czasu HTTP
        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $ar = $tcp.BeginConnect('127.0.0.1', [int]$FB_Port, $null, $null)
            if (-not $ar.AsyncWaitHandle.WaitOne(300) -or -not $tcp.Connected) { return [pscustomobject]@{ Up = $false; Tries = $null } }
        } finally { $tcp.Close() }
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:$FB_Port/status" -TimeoutSec 1
        return [pscustomobject]@{ Up = $true; Tries = $(if ($null -ne $r.tries) { [int]$r.tries } else { $null }) }
    } catch { return [pscustomobject]@{ Up = $false; Tries = $null } }
}

# Stan odświeżamy co kilka sekund (przy okazji synchronizuje plik hosts) albo od razu po zmianie
function Update-Data([switch]$Force) {
    $real = [datetime]::UtcNow
    $ended = $script:St -and $script:St.Active -and $script:St.Until -le (Get-FBNow)
    if ($Force -or -not $script:St -or $ended -or ($real - $script:StAt).TotalSeconds -ge 5) {
        $script:St = Invoke-FBAuto
        $script:StAt = $real
        $script:SiteCount = @(Get-FBListEntries).Count
    }
    if ($Force -or ($real - $script:PageAt).TotalSeconds -ge 15) {
        $script:Page = Get-PageInfo
        $script:PageAt = $real
    }
}

function Set-Flash([string]$Text, [string]$Kind = 'ok') {
    $script:Flash = @{ Text = $Text; Kind = $Kind; Until = [datetime]::UtcNow.AddSeconds(6) }
}

function Get-FlashLine {
    $f = $script:Flash
    if (-not $f -or $f.Until -lt [datetime]::UtcNow) { return , (Ln) }
    $max = (Get-Width) - 6   # jedna linia - zawinięcie zepsułoby rysowanie
    $text = if ($f.Text.Length -gt $max) { $f.Text.Substring(0, $max - 1) + '…' } else { $f.Text }
    switch ($f.Kind) {
        'ok'    { return , (Ln (Seg '  ✔ ' Green) (Seg $text Green)) }
        'warn'  { return , (Ln (Seg '  ! ' Yellow) (Seg $text Yellow)) }
        default { return , (Ln (Seg '  ✖ ' Yellow) (Seg $text Yellow)) }
    }
}

# Pozostały czas z sekundami poniżej godziny, żeby odliczanie tykało
function Format-Remaining([TimeSpan]$Span) {
    if ($Span.TotalSeconds -lt 1) { return '0 s' }
    if ($Span.TotalHours -ge 1) { return (Format-FBDuration $Span) }
    if ($Span.TotalMinutes -ge 1) { return ('{0} min {1:00} s' -f [int][math]::Floor($Span.TotalMinutes), $Span.Seconds) }
    return ('{0} s' -f $Span.Seconds)
}

# ------------------------------------------------------------------ nagłówek

function Get-Rule { return , (Ln (Seg ('  ' + ('─' * ((Get-Width) - 2))) DarkGray)) }

function Get-TitleLine {
    $clock = (Get-FBNow).ToString('HH:mm')
    $pad = [Math]::Max(1, (Get-Width) - 2 - 12 - $clock.Length)
    return , (Ln (Seg '  FocusBlocker' Cyan) (Seg ((' ' * $pad) + $clock) DarkGray))
}

# Pełny nagłówek pulpitu
function Get-HeaderLines {
    $st = $script:St; $now = Get-FBNow
    $L = New-Object 'System.Collections.Generic.List[object]'
    $L.Add((Get-TitleLine)); $L.Add((Get-Rule))
    if ($st.Active) {
        $L.Add((Ln (Seg '  ● ' Red) (Seg (T 'st.active') Red)))
        $L.Add((Ln (Seg '  ' ) (Seg (T 'st.activeLine' (Format-FBWhen $st.Until) (Format-Remaining ($st.Until - $now))) White)))
        if ($st.Since -and $st.Until -gt $st.Since) {
            $pct = [Math]::Min(1.0, [Math]::Max(0.0, ($now - $st.Since).TotalSeconds / ($st.Until - $st.Since).TotalSeconds))
            $bw = [Math]::Min(40, (Get-Width) - 10)
            $filled = [int][Math]::Floor($pct * $bw)
            $L.Add((Ln (Seg '  ') (Seg ('█' * $filled) Red) (Seg ('░' * ($bw - $filled)) DarkGray) (Seg (' {0,3}%' -f [int][Math]::Floor($pct * 100)) Gray)))
        }
        $meta = @(T 'st.reason' (Format-FBReason $st.Reason))
    } else {
        $L.Add((Ln (Seg '  ○ ' Green) (Seg (T 'st.inactive') Green)))
        if ($st.NextStart) {
            $L.Add((Ln (Seg '  ') (Seg (T 'st.next' (Format-FBWhen $st.NextStart) (Format-FBDuration ($st.NextStart - $now))) White)))
        }
        $meta = @()
    }
    if ($null -ne $script:Page.Tries) { $meta += (T 'st.tries' $script:Page.Tries) }
    if ($meta.Count) { $L.Add((Ln (Seg ('  ' + ($meta -join ' · ')) DarkGray))) }
    if ($script:Page.Up) { $L.Add((Ln (Seg ('  ' + (T 'st.page' (T 'menu.pageOk'))) DarkGray))) }
    else { $L.Add((Ln (Seg ('  ' + (T 'st.page' (T 'menu.pageDown'))) Yellow))) }
    $L.Add((Get-Rule))
    return , $L
}

# Skrócony nagłówek podekranów: jedna linia stanu
function Get-CompactHeader {
    $st = $script:St; $now = Get-FBNow
    $L = New-Object 'System.Collections.Generic.List[object]'
    $L.Add((Get-TitleLine)); $L.Add((Get-Rule))
    if ($st.Active) {
        $L.Add((Ln (Seg '  ● ' Red) (Seg (T 'st.active') Red) (Seg ('  ' + (T 'st.activeLine' (Format-FBWhen $st.Until) (Format-Remaining ($st.Until - $now)))) White)))
    } else {
        $L.Add((Ln (Seg '  ○ ' Green) (Seg (T 'st.inactive') Green)))
    }
    $L.Add((Get-Rule))
    return , $L
}

# Wiersz listy z zaznaczeniem: numer/skrót, tekst i opcjonalna wartość po prawej
function Get-ItemLine([bool]$Selected, [string]$Key, [string]$Label, [string]$Hint = '') {
    $bar = (Get-Width) - 1
    if ($Selected) {
        $text = (' ▸ ' + $Key + '  ' + $Label).PadRight($bar - 4) + $Hint.PadLeft(3) + ' '
        return , (Ln (Seg ' ') (Seg $text Black Cyan))
    }
    $pad = ' ' * [Math]::Max(1, ($bar - 3) - ('    ' + $Key + '  ' + $Label).Length)
    return , (Ln (Seg '    ') (Seg $Key Cyan) (Seg ('  ' + $Label) Gray) (Seg ($pad + $Hint.PadLeft(3)) DarkGray))
}

# ------------------------------------------------------------------ blokada

# Ostrzeżenie i potwierdzenie słowem TAK/YES. Nic nie zrobi bez wpisania słowa.
function Confirm-Block([datetime]$Until) {
    $st = $script:St; $now = Get-FBNow
    if ($Until -gt $now.AddDays(7)) { Set-Flash (T 'block.max') 'err'; return }
    if ($st.Active -and $Until -le $st.Until) { Set-Flash (T 'block.longer' (Format-FBWhen $st.Until)) 'err'; return }
    Reset-Screen
    $L = Get-CompactHeader
    $w = (Get-Width) - 2
    $L.Add((Ln))
    $L.Add((Ln (Seg '  ┌─ ' Yellow) (Seg (T 'block.boxTitle') White)))
    $L.Add((Ln (Seg '  │ ' Yellow) (Seg (T 'block.summary' (Format-FBWhen $Until) (Format-FBDuration ($Until - $now))) White)))
    $L.Add((Ln (Seg '  │ ' Yellow) (Seg (T 'block.warn') Yellow)))
    $L.Add((Ln (Seg ('  └' + ('─' * ($w - 1))) Yellow)))
    $L.Add((Ln))
    $L.Add((Ln (Seg ('  ' + (T 'block.typeToConfirm' (T 'block.word'))) Gray)))
    Show-Screen $L
    Move-ToPrompt $L.Count
    $ans = Read-Text '›'
    Reset-Screen
    if ($ans -and $ans -match '^(tak|yes)$') {
        $u = Start-FBManualBlock $Until
        Update-Data -Force
        Set-Flash (T 'block.done' (Format-FBWhen $u)) 'ok'
    } else {
        Set-Flash (T 'ui.cancelled') 'warn'
    }
}

# Szybki start z pulpitu: trwająca blokada jest przedłużana o podany czas
function Invoke-Quick([int]$Minutes) {
    $st = $script:St
    $until = if ($st.Active) { $st.Until.AddMinutes($Minutes) } else { (Get-FBNow).AddMinutes($Minutes) }
    Confirm-Block $until
}

function Menu-Block {
    $opts = @(
        @{ Label = '25 min'; Min = 25 }, @{ Label = '50 min'; Min = 50 },
        @{ Label = (T 'block.90min'); Min = 90 }, @{ Label = '2 h'; Min = 120 },
        @{ Label = (T 'block.endOfDay'); Min = -1 }, @{ Label = (T 'block.custom'); Min = 0 }
    )
    $sel = 0
    Reset-Screen
    while ($true) {
        Update-Data
        $title = $(if ($script:St.Active) { T 'menu.extend' } else { T 'menu.start' }).TrimEnd('…')
        $L = Get-CompactHeader
        $L.Add((Ln))
        $L.Add((Ln (Seg ('  ' + (T 'block.howLong' $title)) White)))
        $L.Add((Ln))
        for ($i = 0; $i -lt $opts.Count; $i++) { $L.Add((Get-ItemLine ($i -eq $sel) ([string]($i + 1)) $opts[$i].Label)) }
        $L.Add((Ln)); $L.Add((Get-FlashLine)); $L.Add((Ln (Seg ('  ' + (T 'ui.helpPick')) DarkGray)))
        Show-Screen $L
        $k = Read-FBKey 1000
        if ($null -eq $k) { continue }
        if (Test-Back $k) { return }
        $pick = $null
        if ($k.Key -eq 'Enter') { $pick = $sel }
        elseif ($k.Char -match '^[1-6]$') { $pick = [int]$k.Char - 1 }
        else { $sel = Move-Selection $sel $opts.Count $k; continue }

        $now = Get-FBNow
        $until = $null
        $m = $opts[$pick].Min
        if ($m -gt 0) { $until = $now.AddMinutes($m) }
        elseif ($m -lt 0) { $until = $now.Date.AddDays(1).AddMinutes(-1) }
        else {
            Move-ToPrompt $L.Count
            $v = Read-Text (T 'block.ask')
            Reset-Screen
            if (-not $v) { continue }
            if ($v -match '^\d{1,2}[:.]\d{2}$') {
                try { $until = $now.Date + (ConvertTo-FBTime $v) } catch { Set-Flash $_.Exception.Message 'err'; continue }
                if ($until -le $now) { $until = $until.AddDays(1) }
            } elseif ($v -match '^\d+$' -and [int]$v -gt 0) {
                $until = $now.AddMinutes([int]$v)
            } else { Set-Flash (T 'block.badValue') 'err'; continue }
        }
        Confirm-Block $until
        return
    }
}

# ------------------------------------------------------------------ lista stron

function Menu-List {
    $sel = 0; $top = 0; $page = 10; $ask = $null
    Reset-Screen
    while ($true) {
        Update-Data
        $list = @(Get-FBListEntries)
        if ($sel -ge $list.Count) { $sel = [Math]::Max(0, $list.Count - 1) }
        if ($sel -lt $top) { $top = $sel } elseif ($sel -ge $top + $page) { $top = $sel - $page + 1 }
        $L = Get-CompactHeader
        $L.Add((Ln))
        $L.Add((Ln (Seg ('  ' + (T 'list.title')) White)))
        $L.Add((Ln (Seg ('  ' + (T 'list.hint')) DarkGray)))
        $L.Add((Ln))
        if ($list.Count -eq 0) { $L.Add((Ln (Seg ('    ' + (T 'list.empty')) DarkGray))) }
        $end = [Math]::Min($list.Count, $top + $page)
        for ($i = $top; $i -lt $end; $i++) { $L.Add((Get-ItemLine ($i -eq $sel) ('{0,2}' -f ($i + 1)) $list[$i])) }
        if ($list.Count -gt $end) { $L.Add((Ln (Seg ('      ' + (T 'list.more' ($list.Count - $end))) DarkGray))) }
        $L.Add((Ln))
        if ($ask) { $L.Add((Ln (Seg ('  ' + $ask) Yellow))) } else { $L.Add((Get-FlashLine)) }
        $L.Add((Ln (Seg ('  ' + $(if ($script:St.Active) { T 'list.helpLocked' } else { T 'list.help' })) DarkGray)))
        Show-Screen $L

        $k = Read-FBKey 1000
        if ($null -eq $k) { continue }
        if ($ask) {   # czekamy na t/y
            $name = $list[$sel]; $ask = $null
            if ($k.Char -match '^[tTyY]$') {
                try { Remove-FBDomain $name; Set-Flash (T 'list.removed' $name) 'ok' } catch { Set-Flash $_.Exception.Message 'err' }
                Update-Data -Force
            }
            continue
        }
        if (Test-Back $k) { return }
        if ($k.Char -match '^[aAdD]$') {   # a/d = add/dodaj
            Move-ToPrompt $L.Count
            $v = Read-Text (T 'list.ask')
            Reset-Screen
            if (-not $v) { continue }
            $done = @(); $bad = @()
            foreach ($part in ($v -split '[,;\s]+' | Where-Object { $_ })) {
                try {
                    if (Add-FBDomain $part) { $done += (ConvertTo-FBDomain $part) } else { $bad += (T 'list.exists' $part) }
                } catch { $bad += $_.Exception.Message }
            }
            [void](Invoke-FBAuto)
            Update-Data -Force
            $msgs = @()
            if ($done.Count) { $msgs += (T 'list.added' ($done -join ', ')) }
            $msgs += $bad
            $kind = if (-not $bad.Count) { 'ok' } elseif ($done.Count) { 'warn' } else { 'err' }
            Set-Flash ($msgs -join ' · ') $kind
            continue
        }
        if ($k.Key -eq 'Delete' -or $k.Char -match '^[rRuU]$') {   # r/u = remove/usuń
            if ($list.Count -eq 0) { continue }
            if ($script:St.Active) { Set-Flash (T 'list.locked') 'err'; continue }
            $ask = (T 'list.removeAsk' $list[$sel]) + ' ' + (T 'menu.yesNo')
            continue
        }
        $sel = Move-Selection $sel $list.Count $k
    }
}

# ------------------------------------------------------------------ harmonogram

$script:GridKey = $null
$script:Grid = $null

# Siatka tygodnia: 7 dni x 48 półgodzin, true = blokada
function Get-ScheduleGrid($Config) {
    $key = ($Config.Schedule | ForEach-Object { "$($_.Days -join ',')|$($_.From)|$($_.To)" }) -join ';'
    if ($script:Grid -and $script:GridKey -eq $key) { return $script:Grid }
    $iv = @(Get-FBIntervals $Config)
    $now = Get-FBNow
    $monday = $now.Date.AddDays(-(([int]$now.DayOfWeek + 6) % 7))
    $rows = for ($d = 0; $d -lt 7; $d++) {
        , @(for ($s = 0; $s -lt 48; $s++) { [bool](Get-FBIntervalEndAt $iv $monday.AddDays($d).AddMinutes(30 * $s)) })
    }
    $script:Grid = @($rows); $script:GridKey = $key
    return $script:Grid
}

function Get-GridLines($Config) {
    $L = New-Object 'System.Collections.Generic.List[object]'
    $grid = Get-ScheduleGrid $Config
    $now = Get-FBNow
    $today = ([int]$now.DayOfWeek + 6) % 7
    $slot = [int][Math]::Floor($now.TimeOfDay.TotalMinutes / 30)
    $short = $FB_DayShort[$FB_State.Lang]
    # oś godzin i znacznik "teraz"
    $axis = (' ' * 48).ToCharArray()
    foreach ($h in 0, 3, 6, 9, 12, 15, 18, 21) { $t = '{0:00}' -f $h; $axis[$h * 2] = $t[0]; $axis[$h * 2 + 1] = $t[1] }
    $mark = (' ' * 48).ToCharArray(); $mark[[Math]::Min(47, $slot)] = '▼'
    $L.Add((Ln (Seg ('       ' + (-join $mark)) Cyan)))
    $L.Add((Ln (Seg ('       ' + (-join $axis)) DarkGray)))
    for ($d = 0; $d -lt 7; $d++) {
        $label = ('{0,-3}' -f $short[$FB_DayOrder[$d]])
        $segs = New-Object 'System.Collections.Generic.List[object]'
        $segs.Add((Seg ('  ' + $label + '  ') $(if ($d -eq $today) { 'Cyan' } else { 'Gray' })))
        $s = 0
        while ($s -lt 48) {
            $v = $grid[$d][$s]; $e = $s
            while ($e + 1 -lt 48 -and $grid[$d][$e + 1] -eq $v) { $e++ }
            $n = $e - $s + 1
            $segs.Add((Seg $(if ($v) { '█' * $n } else { '·' * $n }) $(if ($v) { 'Red' } else { 'DarkGray' })))
            $s = $e + 1
        }
        $L.Add($segs)
    }
    $L.Add((Ln (Seg ('       ' + (T 'sched.legend')) DarkGray)))
    return , $L
}

function Menu-Schedule {
    $sel = 0; $ask = $null
    Reset-Screen
    while ($true) {
        Update-Data
        $cfg = Get-FBConfig
        $entries = @($cfg.Schedule)
        if ($sel -ge $entries.Count) { $sel = [Math]::Max(0, $entries.Count - 1) }
        $L = Get-CompactHeader
        $L.Add((Ln))
        $L.Add((Ln (Seg ('  ' + (T 'sched.title')) White)))
        $L.Add((Ln))
        $L.AddRange((Get-GridLines $cfg))
        $L.Add((Ln))
        if ($entries.Count -eq 0) { $L.Add((Ln (Seg ('    ' + (T 'sched.empty')) DarkGray))) }
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $e = $entries[$i]
            $L.Add((Get-ItemLine ($i -eq $sel) ([string]($i + 1)) ('{0,-18} {1}–{2}' -f (Format-FBDays $e.Days), $e.From, $e.To)))
        }
        $L.Add((Ln))
        if ($ask) { $L.Add((Ln (Seg ('  ' + $ask) Yellow))) } else { $L.Add((Get-FlashLine)) }
        $L.Add((Ln (Seg ('  ' + $(if ($script:St.Active) { T 'sched.helpLocked' } else { T 'sched.help' })) DarkGray)))
        Show-Screen $L

        $k = Read-FBKey 1000
        if ($null -eq $k) { continue }
        if ($ask) {
            $ask = $null
            if ($k.Char -match '^[tTyY]$') {
                $gone = $entries[$sel]
                $cfg.Schedule = @(for ($i = 0; $i -lt $entries.Count; $i++) { if ($i -ne $sel) { $entries[$i] } })
                Save-FBConfig $cfg
                Write-FBLog (T 'log.rangeRemoved' (Format-FBDays $gone.Days) $gone.From $gone.To)
                Update-Data -Force
                Set-Flash (T 'menu.removed') 'ok'
            }
            continue
        }
        if (Test-Back $k) { return }
        if ($k.Char -match '^[aAdD]$') {
            Move-ToPrompt $L.Count
            try {
                $v = Read-Text (T 'sched.askDays'); if (-not $v) { Reset-Screen; continue }
                $days = ConvertFrom-FBDaysInput $v
                $from = Read-Text (T 'sched.askFrom'); if (-not $from) { Reset-Screen; continue }
                [void](ConvertTo-FBTime $from)
                $to = Read-Text (T 'sched.askTo'); if (-not $to) { Reset-Screen; continue }
                [void](ConvertTo-FBTime $to)
                if ((ConvertTo-FBTime $from) -eq (ConvertTo-FBTime $to)) { throw (T 'sched.same') }
            } catch { Reset-Screen; Set-Flash $_.Exception.Message 'err'; continue }
            $new = [pscustomobject]@{ Days = $days; From = (ConvertTo-FBTime $from).ToString('hh\:mm'); To = (ConvertTo-FBTime $to).ToString('hh\:mm') }
            if ($new.To -eq '1.00:00' -or $to -match '^\s*24:00') { $new.To = '24:00' }
            $test = @(Get-FBIntervals ([pscustomobject]@{ Schedule = @($new) }))
            if (Get-FBIntervalEndAt $test (Get-FBNow)) {
                # przedział obejmuje "teraz": blokada ruszy od razu i będzie nie do przerwania
                Write-Host ''
                Write-Host (ConvertTo-Display ('  ! ' + (T 'sched.nowWarn'))) -ForegroundColor Yellow
                Write-Host (ConvertTo-Display ('  ' + (T 'sched.confirm' (T 'block.word')))) -ForegroundColor Gray
                $ans = Read-Text '›'
                if (-not ($ans -and $ans -match '^(tak|yes)$')) { Reset-Screen; Set-Flash (T 'ui.cancelled') 'warn'; continue }
            }
            Reset-Screen
            $cfg.Schedule = @($entries) + $new
            Save-FBConfig $cfg
            Write-FBLog (T 'log.rangeAdded' (Format-FBDays $new.Days) $new.From $new.To)
            [void](Invoke-FBAuto)
            Update-Data -Force
            Set-Flash (T 'sched.added' (Format-FBDays $new.Days) $new.From $new.To) 'ok'
            continue
        }
        if ($k.Key -eq 'Delete' -or $k.Char -match '^[rRuU]$') {
            if ($entries.Count -eq 0) { continue }
            if ($script:St.Active) { Set-Flash (T 'sched.locked') 'err'; continue }
            $e = $entries[$sel]
            $ask = (T 'list.removeAsk' ('{0} {1}–{2}' -f (Format-FBDays $e.Days), $e.From, $e.To)) + ' ' + (T 'menu.yesNo')
            continue
        }
        $sel = Move-Selection $sel $entries.Count $k
    }
}

# ------------------------------------------------------------------ tekst, dziennik, język

function Menu-Message {
    Reset-Screen
    Update-Data
    $cfg = Get-FBConfig
    $L = Get-CompactHeader
    $L.Add((Ln))
    $L.Add((Ln (Seg ('  ' + (T 'msg.title')) White)))
    $current = (T 'msg.current' (([string]$cfg.Message) -replace '\s+', ' '))
    $maxLen = (Get-Width) - 4
    if ($current.Length -gt $maxLen) { $current = $current.Substring(0, $maxLen - 1) + '…' }
    $L.Add((Ln (Seg ('  ' + $current) Gray)))
    $L.Add((Ln))
    $L.Add((Ln (Seg ('  ' + (T 'msg.hint')) DarkGray)))
    Show-Screen $L
    Move-ToPrompt $L.Count
    $v = Read-Text (T 'msg.ask')
    Reset-Screen
    if (-not $v) { return }
    $cfg.Message = if ($v -eq '-') { T 'default.message' } else { $v }
    Save-FBConfig $cfg
    Set-Flash (T 'msg.saved') 'ok'
}

function Menu-Log {
    Reset-Screen
    Update-Data
    $L = Get-CompactHeader
    $L.Add((Ln))
    $L.Add((Ln (Seg ('  ' + (T 'log.title')) White)))
    $L.Add((Ln))
    $max = (Get-Width) - 4
    if (Test-Path $FB_LogPath) {
        foreach ($line in (Get-Content $FB_LogPath -Tail 18 -Encoding UTF8)) {
            $t = [string]$line
            if ($t.Length -gt $max) { $t = $t.Substring(0, $max - 1) + '…' }
            $L.Add((Ln (Seg ('  ' + $t) Gray)))
        }
    } else { $L.Add((Ln (Seg ('    ' + (T 'log.empty')) DarkGray))) }
    $L.Add((Ln)); $L.Add((Ln (Seg ('  ' + (T 'ui.helpBack')) DarkGray)))
    Show-Screen $L
    while ($true) {
        $k = Read-FBKey 0
        if ((Test-Back $k) -or $k.Key -eq 'Enter') { break }
    }
    Reset-Screen
}

function Menu-Language {
    $codes = @($FB_Languages.Keys)
    $sel = [Math]::Max(0, [array]::IndexOf($codes, $FB_State.Lang))
    Reset-Screen
    while ($true) {
        Update-Data
        $L = Get-CompactHeader
        $L.Add((Ln)); $L.Add((Ln (Seg '  Język / Language' White))); $L.Add((Ln))
        for ($i = 0; $i -lt $codes.Count; $i++) {
            $L.Add((Get-ItemLine ($i -eq $sel) ([string]($i + 1)) $FB_Languages[$codes[$i]] $(if ($codes[$i] -eq $FB_State.Lang) { '✔' } else { '' })))
        }
        $L.Add((Ln)); $L.Add((Ln (Seg ('  ' + (T 'ui.helpPick')) DarkGray)))
        Show-Screen $L
        $k = Read-FBKey 1000
        if ($null -eq $k) { continue }
        if (Test-Back $k) { return }
        if ($k.Key -eq 'Enter' -or $k.Char -match '^[1-9]$') {
            $n = if ($k.Key -eq 'Enter') { $sel } else { [int]$k.Char - 1 }
            if ($n -ge $codes.Count) { continue }
            $cfg = Get-FBConfig
            $cfg.Language = $codes[$n]
            Save-FBConfig $cfg
            Update-FBLanguage $null
            $script:Grid = $null
            Write-FBLog (T 'log.language' $FB_Languages[$FB_State.Lang])
            Set-Flash (T 'lang.saved' $FB_Languages[$FB_State.Lang]) 'ok'
            return
        }
        $sel = Move-Selection $sel $codes.Count $k
    }
}

# ------------------------------------------------------------------ pulpit

function Get-MainItems {
    $active = $script:St.Active
    return @(
        @{ Id = 'block';    Key = (T 'key.block');    Label = $(if ($active) { T 'menu.extend' } else { T 'menu.start' }); Hint = '' }
        @{ Id = 'list';     Key = (T 'key.list');     Label = (T 'menu.list');     Hint = [string]$script:SiteCount }
        @{ Id = 'schedule'; Key = (T 'key.schedule'); Label = (T 'menu.schedule'); Hint = [string]@($script:St.Config.Schedule).Count }
        @{ Id = 'message';  Key = (T 'key.message');  Label = (T 'menu.message');  Hint = '' }
        @{ Id = 'log';      Key = (T 'key.log');      Label = (T 'menu.log');      Hint = '' }
        @{ Id = 'language'; Key = (T 'key.language'); Label = (T 'menu.language'); Hint = '' }
        @{ Id = 'exit';     Key = (T 'key.exit');     Label = (T 'menu.exit');     Hint = '' }
    )
}

$script:QuickMinutes = @(25, 50, 90, 120)

function Get-MainLines($Items, [int]$Sel) {
    $L = New-Object 'System.Collections.Generic.List[object]'
    $L.AddRange((Get-HeaderLines))
    $labels = @('25 min', '50 min', (T 'block.90min'), '2 h')
    $title = if ($script:St.Active) { T 'menu.quickExtend' } else { T 'menu.quick' }
    $segs = New-Object 'System.Collections.Generic.List[object]'
    $segs.Add((Seg ('  ' + $title.PadRight(14)) DarkGray))
    for ($i = 0; $i -lt 4; $i++) { $segs.Add((Seg ([string]($i + 1)) Cyan)); $segs.Add((Seg (' ' + $labels[$i] + '   ') White)) }
    $L.Add($segs)
    $L.Add((Ln))
    for ($i = 0; $i -lt $Items.Count; $i++) { $L.Add((Get-ItemLine ($i -eq $Sel) $Items[$i].Key $Items[$i].Label $Items[$i].Hint)) }
    $L.Add((Ln))
    $L.Add((Get-FlashLine))
    $L.Add((Ln (Seg ('  ' + (T 'ui.helpMain')) DarkGray)))
    return , $L
}

$sel = 0
$quit = $false
Set-Cursor $false
try {
    Reset-Screen
    Update-Data -Force
    while (-not $quit) {
        try {
            Update-Data
            $items = Get-MainItems
            if ($sel -ge $items.Count) { $sel = 0 }
            Show-Screen (Get-MainLines $items $sel)
            $k = Read-FBKey 1000
            if ($null -eq $k) { continue }
            if ($k.Key -eq 'Eof') { break }
            $action = $null
            if ($k.Key -eq 'Enter') { $action = $items[$sel].Id }
            elseif ($k.Key -eq 'Escape') { $action = 'exit' }
            elseif ($k.Char -match '^[1-4]$') { $action = 'quick' + $k.Char }
            elseif ($k.Char) {
                $hit = @($items | Where-Object { $_.Key.ToUpperInvariant() -eq $k.Char.ToUpperInvariant() })
                if ($hit.Count) { $action = $hit[0].Id; $sel = [array]::IndexOf(@($items | ForEach-Object { $_.Id }), $action) }
            }
            if (-not $action) { $sel = Move-Selection $sel $items.Count $k; continue }
            switch -Regex ($action) {
                '^block$'    { Menu-Block }
                '^list$'     { Menu-List }
                '^schedule$' { Menu-Schedule }
                '^message$'  { Menu-Message }
                '^log$'      { Menu-Log }
                '^language$' { Menu-Language }
                '^quick\d$'  { Invoke-Quick $script:QuickMinutes[[int]$action.Substring(5) - 1] }
                '^exit$'     { $quit = $true }
            }
            Reset-Screen
            Update-Data -Force
        } catch {
            Reset-Screen
            Set-Flash $_.Exception.Message 'err'
        }
    }
} finally {
    Set-Cursor $true
    if (-not $FB_NoClear) { Clear-Host }
}
