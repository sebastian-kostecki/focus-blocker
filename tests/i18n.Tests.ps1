#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
# Testy tłumaczeń (i18n.ps1) i wyboru języka. Uruchomienie:  Invoke-Pester .\tests

BeforeAll {
    $FB_Dir       = Join-Path $TestDrive 'fb'
    $FB_HostsPath = Join-Path $TestDrive 'hosts'
    New-Item -ItemType Directory -Path $FB_Dir -Force | Out-Null
    . (Join-Path $PSScriptRoot '..\lib.ps1')

    function Set-TestConfig($Language, $Message = '') {
        $obj = [ordered]@{ schedule = @(); message = $Message }
        if ($Language) { $obj.language = $Language }
        [IO.File]::WriteAllText($FB_ConfigPath, (ConvertTo-Json -InputObject $obj -Depth 5))
    }
    function Get-Placeholders([string]$Text) {
        @([regex]::Matches($Text, '\{(\d+)[^}]*\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    }
}

Describe 'Tabela tekstów' {
    It 'każdy klucz ma wersję polską i angielską' {
        $pl = @($FB_Text.pl.Keys); $en = @($FB_Text.en.Keys)
        @($pl | Where-Object { $_ -notin $en }) | Should -BeNullOrEmpty
        @($en | Where-Object { $_ -notin $pl }) | Should -BeNullOrEmpty
    }

    It 'oba języki używają tych samych placeholderów {0}, {1}…' {
        $bad = foreach ($k in $FB_Text.pl.Keys) {
            $plP = (Get-Placeholders $FB_Text.pl[$k]) -join ','
            $enP = (Get-Placeholders $FB_Text.en[$k]) -join ','
            if ($FB_Text.en.ContainsKey($k) -and $plP -ne $enP) { $k }
        }
        $bad | Should -BeNullOrEmpty
    }

    It 'żaden tekst nie jest pusty' {
        foreach ($l in 'pl', 'en') {
            @($FB_Text[$l].Keys | Where-Object { -not $FB_Text[$l][$_] }) | Should -BeNullOrEmpty
        }
    }

    It 'każdy język ma skróty dni tygodnia' {
        foreach ($l in $FB_Text.Keys) { $FB_DayShort[$l].Count | Should -Be 7 }
    }

    It 'każdy klucz użyty w skryptach (T ''klucz'') istnieje w tabeli' {
        $root = Join-Path $PSScriptRoot '..'
        $used = foreach ($f in Get-ChildItem $root -Filter *.ps1 | Where-Object Name -ne 'i18n.ps1') {
            [regex]::Matches([IO.File]::ReadAllText($f.FullName), "\bT '([A-Za-z0-9.]+)'") | ForEach-Object { $_.Groups[1].Value }
        }
        $used = @($used | Sort-Object -Unique)
        $used.Count | Should -BeGreaterThan 100
        @($used | Where-Object { -not $FB_Text.pl.ContainsKey($_) }) | Should -BeNullOrEmpty
    }

    It 'każdy klucz z tabeli jest gdzieś używany' {
        $root = Join-Path $PSScriptRoot '..'
        $code = (Get-ChildItem $root -Filter *.ps1 | Where-Object Name -ne 'i18n.ps1' | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
        $unused = @($FB_Text.pl.Keys | Where-Object { $_ -notlike 'reason.*' -and $code -notmatch ("T '" + [regex]::Escape($_) + "'") })
        $unused | Should -BeNullOrEmpty
    }

    It 'teksty rysowane w jednej linii pulpitu mieszczą się w 58 znakach' {
        # dłuższa linia zawinęłaby się w terminalu i zepsuła rysowanie ekranu
        $keys = @($FB_Text.pl.Keys | Where-Object { $_ -match '^(ui\.help|list\.help|sched\.help|msg\.hint|list\.hint|sched\.title|sched\.legend|block\.typeToConfirm|sched\.confirm|st\.)' })
        $keys.Count | Should -BeGreaterThan 10
        $tooLong = foreach ($l in 'pl', 'en') {
            foreach ($k in $keys) {
                $fill = if ($k -match 'confirm|typeToConfirm') { 'XXX' } else { 'XXXXXXXXXXXX' }   # słowo TAK/YES albo ~12 znaków (godzina, czas)
                $filled = [regex]::Replace($FB_Text[$l][$k], '\{\d+[^}]*\}', $fill)
                if ($filled.Length -gt 58) { "$l/$k ($($filled.Length))" }
            }
        }
        $tooLong | Should -BeNullOrEmpty
    }

    It 'T zwraca klucz, gdy tekstu brak' {
        T 'no.such.key' | Should -Be 'no.such.key'
    }

    It 'T wypełnia placeholdery' {
        $FB_State.Lang = 'en'
        T 'dur.lessThanMinute' | Should -Be 'less than a minute'
        T 'st.next' '14:00' '5 min' | Should -Be 'next: 14:00 (in 5 min)'
    }
}

Describe 'Wybór języka' {
    It 'bierze język z config.json: <Lang>' -ForEach @(@{ Lang = 'pl' }, @{ Lang = 'en' }) {
        Set-TestConfig $Lang
        [void](Get-FBConfig)
        $FB_State.Lang | Should -Be $Lang
    }

    It 'nieznany język w configu zastępuje język systemu' {
        Set-TestConfig 'xx'
        [void](Get-FBConfig)
        $FB_State.Lang | Should -BeIn 'pl', 'en'
    }

    It 'bez wpisu w configu używa języka systemu' {
        Set-TestConfig $null
        [void](Get-FBConfig)
        $FB_State.Lang | Should -Be (Get-FBSystemLanguage)
    }

    It 'zmiana języka przez Save-FBConfig zostaje zapamiętana' {
        Set-TestConfig 'pl'
        $cfg = Get-FBConfig
        $cfg.Language = 'en'
        Save-FBConfig $cfg
        [void](Get-FBConfig)
        $FB_State.Lang | Should -Be 'en'
    }
}

Describe 'Komunikat na stronie blokady' {
    It 'domyślny komunikat podąża za językiem' {
        Set-TestConfig 'en'
        (Get-FBConfig).Message | Should -Be $FB_Text.en['default.message']
        Set-TestConfig 'pl'
        (Get-FBConfig).Message | Should -Be $FB_Text.pl['default.message']
    }

    It 'domyślny komunikat w innym języku niż bieżący też jest traktowany jako domyślny' {
        Set-TestConfig 'en' $FB_Text.pl['default.message']
        (Get-FBConfig).Message | Should -Be $FB_Text.en['default.message']
    }

    It 'własny komunikat zostaje przy zmianie języka' {
        Set-TestConfig 'pl' 'Do roboty!'
        $cfg = Get-FBConfig
        $cfg.Language = 'en'
        Save-FBConfig $cfg
        (Get-FBConfig).Message | Should -Be 'Do roboty!'
    }

    It 'zapisanie domyślnego komunikatu zostawia w configu pusty tekst' {
        Set-TestConfig 'pl'
        $cfg = Get-FBConfig
        Save-FBConfig $cfg
        (Get-Content $FB_ConfigPath -Raw | ConvertFrom-Json).message | Should -BeNullOrEmpty
    }
}

Describe 'Formatowanie w języku angielskim' {
    BeforeEach { $FB_State.Lang = 'en' }

    It 'Format-FBDays: <Days> -> "<Expected>"' -ForEach @(
        @{ Days = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'; Expected = 'Mon–Fri' }
        @{ Days = 'Saturday', 'Sunday'; Expected = 'Sat, Sun' }
        @{ Days = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'; Expected = 'Every day' }
    ) {
        Format-FBDays $Days | Should -Be $Expected
    }

    It 'Format-FBDuration' {
        Format-FBDuration ([TimeSpan]'01:30:00') | Should -Be '1 h 30 min'
        Format-FBDuration ([TimeSpan]'00:00:20') | Should -Be 'less than a minute'
    }

    It 'Format-FBReason składa powody w bieżącym języku' {
        Format-FBReason 'schedule+manual' | Should -Be 'schedule + manual'
        $FB_State.Lang = 'pl'
        Format-FBReason 'manual+schedule' | Should -Be 'ręczna + harmonogram'
    }

    It 'Format-FBWhen: jutro i dalsze dni' {
        $FB_FakeNow = [datetime]'2026-11-09T10:00:00'
        Format-FBWhen ([datetime]'2026-11-10T09:00:00') | Should -Be 'tomorrow 09:00'
        Format-FBWhen ([datetime]'2026-11-13T09:00:00') | Should -Be 'Fri Nov 13, 09:00'
    }

    It 'angielskie komendy dni działają niezależnie od języka: <Text>' -ForEach @(
        @{ Text = 'daily' }, @{ Text = 'every day' }
    ) {
        @(ConvertFrom-FBDaysInput $Text).Count | Should -Be 7
    }
}
