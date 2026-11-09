# FocusBlocker - wspólne funkcje. Ładowane przez inne skrypty (dot-source):  . "$PSScriptRoot\lib.ps1"
#
# Zasada działania:
#   * Blokada jest AKTYWNA, gdy trwa przedział z harmonogramu (config.json)
#     albo blokada ręczna (state.json -> overrideUntil).
#   * Gdy jest aktywna, do pliku hosts trafia oznaczona sekcja kierująca
#     domeny z blocklist.txt na 0.0.0.0 / ::. Gdy nie jest, sekcja znika.
#   * Aktywnej blokady nie da się skrócić - nie ma takiej funkcji.

if (-not $FB_Dir)       { $FB_Dir = $PSScriptRoot }
if (-not $FB_HostsPath) { $FB_HostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts' }
if (-not $FB_Port)      { $FB_Port = 47615 }

$FB_BlocklistPath = Join-Path $FB_Dir 'blocklist.txt'
$FB_ConfigPath    = Join-Path $FB_Dir 'config.json'
$FB_StatePath     = Join-Path $FB_Dir 'state.json'
$FB_LogPath       = Join-Path $FB_Dir 'blocker.log'

# Znaczniki sekcji w pliku hosts - NIE zmieniać, inaczej nowa wersja nie znajdzie sekcji starej
$FB_MarkerStart = '# >>> FocusBlocker START - sekcja zarzadzana automatycznie, nie edytuj'
$FB_MarkerEnd   = '# <<< FocusBlocker END'

. (Join-Path $PSScriptRoot 'i18n.ps1')

$FB_Inv = [Globalization.CultureInfo]::InvariantCulture

$FB_DayOrder = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')
$FB_DayShortEn = $FB_DayShort.en   # zapis dni w config.json
$FB_DayMap = @{
    mon = 'Monday';    pon = 'Monday';    monday    = 'Monday';    poniedzialek = 'Monday'
    tue = 'Tuesday';   wt  = 'Tuesday';   tuesday   = 'Tuesday';   wtorek       = 'Tuesday'
    wed = 'Wednesday'; sr  = 'Wednesday'; wednesday = 'Wednesday'; sroda        = 'Wednesday'
    thu = 'Thursday';  czw = 'Thursday';  thursday  = 'Thursday';  czwartek     = 'Thursday'
    fri = 'Friday';    pt  = 'Friday';    friday    = 'Friday';    piatek       = 'Friday'
    sat = 'Saturday';  sob = 'Saturday';  saturday  = 'Saturday';  sobota       = 'Saturday'
    sun = 'Sunday';    nd  = 'Sunday';    sunday    = 'Sunday';    niedziela    = 'Sunday'; ndz = 'Sunday'
}

# ------------------------------------------------------------------ ogólne

function Get-FBNow {
    if ($FB_FakeNow) { return [datetime]$FB_FakeNow }   # tylko do testów
    return Get-Date
}

function Write-FBLog([string]$Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
    try {
        if ((Test-Path $FB_LogPath) -and (Get-Item $FB_LogPath).Length -gt 200KB) {
            $tail = Get-Content $FB_LogPath -Tail 500 -Encoding UTF8
            Set-Content -Path $FB_LogPath -Value $tail -Encoding UTF8
        }
        Add-Content -Path $FB_LogPath -Value $line -Encoding UTF8
    } catch { }
}

function Test-FBAdmin {
    if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) { return $true }   # testy poza Windows
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Remove-FBDiacritics([string]$Text) {
    $map = @{ 'ą' = 'a'; 'ć' = 'c'; 'ę' = 'e'; 'ł' = 'l'; 'ń' = 'n'; 'ó' = 'o'; 'ś' = 's'; 'ź' = 'z'; 'ż' = 'z' }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        $k = [string]$ch
        if ($map.ContainsKey($k)) { [void]$sb.Append($map[$k]) } else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

function Format-FBDuration([TimeSpan]$Span) {
    if ($Span.TotalMinutes -lt 1) { return (T 'dur.lessThanMinute') }
    $h = [int][math]::Floor($Span.TotalHours)
    $m = $Span.Minutes
    if ($h -ge 24) { return '{0} d {1} h' -f [int][math]::Floor($Span.TotalDays), $Span.Hours }
    if ($h -gt 0)  { return '{0} h {1} min' -f $h, $m }
    return '{0} min' -f [int][math]::Ceiling($Span.TotalMinutes)
}

function Format-FBWhen([datetime]$At) {
    $now = Get-FBNow
    if ($At.Date -eq $now.Date)            { return $At.ToString('HH:mm') }
    if ($At.Date -eq $now.Date.AddDays(1)) { return (T 'when.tomorrow' $At.ToString('HH:mm')) }
    return $FB_DayShort[$FB_State.Lang][$At.DayOfWeek.ToString()] + ' ' + $At.ToString((T 'when.date'), $FB_Inv)
}

# Kod powodu (np. "schedule+manual") -> tekst w bieżącym języku
function Format-FBReason([string]$Code) {
    return (($Code -split '\+' | ForEach-Object { T "reason.$_" }) -join ' + ')
}

# Język z config.json; gdy go brak - język systemu
function Update-FBLanguage($Raw) {
    if (-not $Raw -and (Test-Path $FB_ConfigPath)) {
        try { $Raw = Get-Content $FB_ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
    }
    $lang = if ($Raw) { [string]$Raw.language } else { '' }
    $FB_State.Lang = if ($lang -and $FB_Text.ContainsKey($lang)) { $lang.ToLowerInvariant() } else { Get-FBSystemLanguage }
}

# ------------------------------------------------------------------ konfiguracja / harmonogram

function ConvertTo-FBTime([string]$Text) {
    if ($Text -match '^\s*24:00\s*$') { return [TimeSpan]::FromDays(1) }
    if ($Text -notmatch '^\s*(\d{1,2})[:.](\d{2})\s*$' -or [int]$Matches[1] -gt 23 -or [int]$Matches[2] -gt 59) {
        throw (T 'err.time' $Text)
    }
    return New-Object TimeSpan -ArgumentList @([int]$Matches[1], [int]$Matches[2], 0)
}

function ConvertTo-FBDay([string]$Text) {
    $key = Remove-FBDiacritics ($Text.Trim().ToLowerInvariant())
    if (-not $FB_DayMap.ContainsKey($key)) { throw (T 'err.day' $Text) }
    return $FB_DayMap[$key]
}

# "pon-pt", "pon,sr,pt", "sob nd", "codziennie" -> tablica nazw angielskich w kolejności tygodnia
function ConvertFrom-FBDaysInput([string]$Text) {
    $t = $Text.Trim().ToLowerInvariant()
    if ($t -in @('codziennie', 'wszystkie', '*', 'daily', 'everyday', 'every day', 'all')) { return $FB_DayOrder }
    $picked = @{}
    foreach ($tok in ($t -split '[,;\s]+' | Where-Object { $_ })) {
        if ($tok -match '^([^-–]+)[-–]([^-–]+)$') {
            $a = [array]::IndexOf($FB_DayOrder, (ConvertTo-FBDay $Matches[1]))
            $b = [array]::IndexOf($FB_DayOrder, (ConvertTo-FBDay $Matches[2]))
            $i = $a
            while ($true) { $picked[$FB_DayOrder[$i]] = $true; if ($i -eq $b) { break }; $i = ($i + 1) % 7 }
        } else {
            $picked[(ConvertTo-FBDay $tok)] = $true
        }
    }
    if ($picked.Count -eq 0) { throw (T 'err.noDays') }
    return @($FB_DayOrder | Where-Object { $picked.ContainsKey($_) })
}

# tablica nazw angielskich -> "Pon–Pt", "Pon, Śr, Pt", "Codziennie"
function Format-FBDays($Days) {
    $idx = @($Days | ForEach-Object { [array]::IndexOf($FB_DayOrder, $_) } | Sort-Object -Unique)
    if ($idx.Count -eq 7) { return (T 'days.every') }
    $short = $FB_DayShort[$FB_State.Lang]
    $parts = @(); $i = 0
    while ($i -lt $idx.Count) {
        $j = $i
        while ($j + 1 -lt $idx.Count -and $idx[$j + 1] -eq $idx[$j] + 1) { $j++ }
        $a = $short[$FB_DayOrder[$idx[$i]]]; $b = $short[$FB_DayOrder[$idx[$j]]]
        if ($j - $i -ge 2)     { $parts += "$a–$b" }
        elseif ($j -gt $i)     { $parts += $a; $parts += $b }
        else                   { $parts += $a }
        $i = $j + 1
    }
    return ($parts -join ', ')
}

function Test-FBDefaultMessage([string]$Text) {
    if (-not $Text) { return $true }
    foreach ($l in $FB_Text.Keys) { if ($Text -eq $FB_Text[$l]['default.message']) { return $true } }
    return $false
}

function Get-FBConfig {
    if (-not (Test-Path $FB_ConfigPath)) { throw (T 'err.missingFile' $FB_ConfigPath) }
    $raw = Get-Content $FB_ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Update-FBLanguage $raw
    $entries = @()
    foreach ($s in @($raw.schedule)) {
        if (-not $s) { continue }
        $entries += [pscustomobject]@{
            Days = @(@($s.days) | ForEach-Object { ConvertTo-FBDay ([string]$_) })
            From = [string]$s.from
            To   = [string]$s.to
        }
    }
    # Pusty tekst albo domyślny w dowolnym języku = domyślny komunikat w bieżącym języku
    $msg = if ($raw.message -and -not (Test-FBDefaultMessage ([string]$raw.message))) { [string]$raw.message } else { T 'default.message' }
    return [pscustomobject]@{ Schedule = $entries; Message = $msg; Language = $FB_State.Lang }
}

function Save-FBConfig($Config) {
    $sched = New-Object System.Collections.ArrayList
    foreach ($e in @($Config.Schedule)) {
        [void]$sched.Add([ordered]@{
            days = [string[]]@($e.Days | ForEach-Object { $FB_DayShortEn[$_] })
            from = $e.From
            to   = $e.To
        })
    }
    $custom = if (Test-FBDefaultMessage ([string]$Config.Message)) { '' } else { $Config.Message }
    $obj = [ordered]@{ language = $Config.Language; schedule = $sched.ToArray(); message = $custom }
    $json = ConvertTo-Json -InputObject $obj -Depth 5
    [IO.File]::WriteAllText($FB_ConfigPath, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# Przedziały w postaci obliczeniowej
function Get-FBIntervals($Config) {
    foreach ($e in @($Config.Schedule)) {
        [pscustomobject]@{ Days = $e.Days; From = (ConvertTo-FBTime $e.From); To = (ConvertTo-FBTime $e.To) }
    }
}

# Zwraca koniec przedziału, który obejmuje chwilę $At, albo $null
function Get-FBIntervalEndAt($Intervals, [datetime]$At) {
    $t = $At.TimeOfDay
    $today = $At.DayOfWeek.ToString()
    $yday = $At.AddDays(-1).DayOfWeek.ToString()
    $best = $null
    foreach ($iv in @($Intervals)) {
        $end = $null
        if ($iv.From -lt $iv.To) {
            if ($iv.Days -contains $today -and $t -ge $iv.From -and $t -lt $iv.To) { $end = $At.Date + $iv.To }
        } elseif ($iv.From -gt $iv.To) {
            if ($iv.Days -contains $today -and $t -ge $iv.From) { $end = $At.Date.AddDays(1) + $iv.To }
            elseif ($iv.Days -contains $yday -and $t -lt $iv.To) { $end = $At.Date + $iv.To }
        }
        if ($end -and (-not $best -or $end -gt $best)) { $best = $end }
    }
    return $best
}

# Koniec ciągłej blokady z harmonogramu (łączy przedziały stykające się lub nakładające)
function Get-FBScheduleEnd($Intervals, [datetime]$At) {
    $end = Get-FBIntervalEndAt $Intervals $At
    if (-not $end) { return $null }
    for ($i = 0; $i -lt 50; $i++) {
        $next = Get-FBIntervalEndAt $Intervals $end
        if (-not $next -or $next -le $end) { break }
        $end = $next
    }
    return $end
}

# Najbliższy początek przedziału po $At
function Get-FBNextStart($Intervals, [datetime]$At) {
    $best = $null
    for ($d = 0; $d -le 7; $d++) {
        $date = $At.Date.AddDays($d)
        foreach ($iv in @($Intervals)) {
            if ($iv.From -eq $iv.To) { continue }
            if ($iv.Days -contains $date.DayOfWeek.ToString()) {
                $start = $date + $iv.From
                if ($start -gt $At -and (-not $best -or $start -lt $best)) { $best = $start }
            }
        }
    }
    return $best
}

# ------------------------------------------------------------------ lista stron

function ConvertTo-FBDomain([string]$Text) {
    $d = ($Text -replace '#.*$', '').Trim().ToLowerInvariant()
    if (-not $d) { return $null }
    $d = $d -replace '^[a-z]+://', ''
    $d = ($d -split '[/?:]')[0].Trim('.')
    $d = $d -replace '^www\.', ''
    if ($d -notmatch '^([a-z0-9-]+\.)+[a-z0-9-]{2,}$') { return $null }
    return $d
}

# Wpisy z pliku (bez komentarzy), w kolejności z pliku
function Get-FBListEntries {
    if (-not (Test-Path $FB_BlocklistPath)) { return @() }
    $out = @()
    foreach ($raw in Get-Content $FB_BlocklistPath -Encoding UTF8) {
        $d = ConvertTo-FBDomain $raw
        if ($d -and $out -notcontains $d) { $out += $d }
    }
    return $out
}

# Pełna lista do pliku hosts (z www. i m.)
function Get-FBDomains {
    $set = New-Object 'System.Collections.Generic.SortedSet[string]'
    foreach ($d in Get-FBListEntries) {
        [void]$set.Add($d)
        if ($d.Split('.').Count -eq 2) { [void]$set.Add("www.$d"); [void]$set.Add("m.$d") }
    }
    return @($set)
}

function Add-FBDomain([string]$Text) {
    $d = ConvertTo-FBDomain $Text
    if (-not $d) { throw (T 'err.notDomain' $Text) }
    if ((Get-FBListEntries) -contains $d) { return $false }
    $enc = New-Object System.Text.UTF8Encoding($false)
    $content = if (Test-Path $FB_BlocklistPath) { [IO.File]::ReadAllText($FB_BlocklistPath) } else { '' }
    if ($content -and -not $content.EndsWith("`n")) { $content += "`r`n" }
    [IO.File]::WriteAllText($FB_BlocklistPath, $content + $d + "`r`n", $enc)
    Write-FBLog (T 'log.added' $d)
    return $true
}

function Remove-FBDomain([string]$Domain) {
    if ((Get-FBStatus).Active) { throw (T 'err.removeDuringBlock') }
    $lines = Get-Content $FB_BlocklistPath -Encoding UTF8
    $kept = @($lines | Where-Object { (ConvertTo-FBDomain $_) -ne $Domain })
    [IO.File]::WriteAllText($FB_BlocklistPath, (($kept -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    Write-FBLog (T 'log.removed' $Domain)
}

# ------------------------------------------------------------------ stan (blokada ręczna)

function Get-FBOverrideUntil {
    if (-not (Test-Path $FB_StatePath)) { return $null }
    try {
        $s = Get-Content $FB_StatePath -Raw | ConvertFrom-Json
        if (-not $s.overrideUntil) { return $null }
        $u = if ($s.overrideUntil -is [datetime]) { $s.overrideUntil } else { [datetime]::Parse([string]$s.overrideUntil, $FB_Inv) }
        if ($u -gt (Get-FBNow)) { return $u }
    } catch { }
    return $null
}

function Start-FBManualBlock([datetime]$Until) {
    $current = Get-FBOverrideUntil
    if ($current -and $current -ge $Until) { return $current }   # nigdy nie skracamy
    $obj = [ordered]@{ overrideUntil = $Until.ToString('s', $FB_Inv) }
    (ConvertTo-Json -InputObject $obj) | Set-Content -Path $FB_StatePath -Encoding UTF8
    Write-FBLog (T 'log.manual' $Until.ToString('yyyy-MM-dd HH:mm'))
    [void](Invoke-FBAuto)
    return $Until
}

# ------------------------------------------------------------------ status

function Get-FBStatus {
    $now = Get-FBNow
    $cfg = Get-FBConfig
    $iv = @(Get-FBIntervals $cfg)
    $schedEnd = Get-FBScheduleEnd $iv $now
    $manual = Get-FBOverrideUntil

    $until = $null; $reason = $null
    if ($schedEnd) { $until = $schedEnd; $reason = 'schedule' }
    if ($manual -and (-not $until -or $manual -gt $until)) {
        $until = $manual
        $reason = if ($schedEnd) { 'schedule+manual' } else { 'manual' }
    }
    # jeśli po końcu blokady od razu zaczyna się kolejny przedział - doliczamy go
    if ($until) {
        for ($i = 0; $i -lt 20; $i++) {
            $more = Get-FBScheduleEnd $iv $until
            if (-not $more -or $more -le $until) { break }
            $until = $more
            if ($reason -eq 'manual') { $reason = 'manual+schedule' }
        }
    }
    [pscustomobject]@{
        Active    = [bool]$until
        Reason    = $reason
        Until     = $until
        NextStart = if ($until) { $null } else { Get-FBNextStart $iv $now }
        Domains   = @(Get-FBDomains)
        Message   = $cfg.Message
        Config    = $cfg
    }
}

# ------------------------------------------------------------------ plik hosts

function Read-FBHosts {
    if (-not (Test-Path $FB_HostsPath)) { return '' }
    return [IO.File]::ReadAllText($FB_HostsPath)
}

function Test-FBHostsBlocked { return (Read-FBHosts).Contains($FB_MarkerStart) }

function Set-FBHostsBlocked([bool]$Blocked, [string]$Reason) {
    $current = Read-FBHosts
    $pattern = '(?ms)^' + [regex]::Escape($FB_MarkerStart) + '.*?^' + [regex]::Escape($FB_MarkerEnd) + '[^\r\n]*(\r?\n)?'
    $clean = [regex]::Replace($current, $pattern, '')
    if ($Blocked) {
        $domains = Get-FBDomains
        $lines = @($FB_MarkerStart)
        foreach ($d in $domains) { $lines += "0.0.0.0 $d"; $lines += ":: $d" }
        $lines += $FB_MarkerEnd
        $new = $clean.TrimEnd() + "`r`n`r`n" + ($lines -join "`r`n") + "`r`n"
    } else {
        $new = $clean.TrimEnd() + "`r`n"
    }
    if ($new -eq $current) { return }

    $backup = Join-Path $FB_Dir 'hosts.backup'
    if ((Test-Path $FB_HostsPath) -and -not (Test-Path $backup)) { Copy-Item $FB_HostsPath $backup }
    $item = Get-Item $FB_HostsPath -ErrorAction SilentlyContinue
    if ($item -and $item.IsReadOnly) { $item.IsReadOnly = $false }

    $enc = New-Object System.Text.UTF8Encoding($false)
    for ($i = 1; $i -le 10; $i++) {
        try { [IO.File]::WriteAllText($FB_HostsPath, $new, $enc); break }
        catch {
            if ($i -eq 10) { throw (T 'err.hostsWrite' $_.Exception.Message) }
            Start-Sleep -Milliseconds 300
        }
    }
    if ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows) {
        try { Clear-DnsClientCache } catch { & ipconfig.exe /flushdns | Out-Null }
    }
    if ($Blocked) { Write-FBLog (T 'log.on' $domains.Count $Reason) } else { Write-FBLog (T 'log.off' $Reason) }
}

# Doprowadza plik hosts do stanu zgodnego ze statusem
function Invoke-FBAuto {
    $st = Get-FBStatus
    if ($st.Active) { Set-FBHostsBlocked $true (T 'log.auto' (Format-FBReason $st.Reason) $st.Until.ToString('yyyy-MM-dd HH:mm')) }
    else            { Set-FBHostsBlocked $false (T 'log.noBlock') }
    return $st
}
