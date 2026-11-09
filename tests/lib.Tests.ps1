#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
# Testy wspólnych funkcji (lib.ps1). Uruchomienie:  Invoke-Pester .\tests
# Wszystko dzieje się w katalogu tymczasowym Pestera - prawdziwy plik hosts nie jest ruszany.

BeforeAll {
    $FB_Dir       = Join-Path $TestDrive 'fb'
    $FB_HostsPath = Join-Path $TestDrive 'hosts'
    New-Item -ItemType Directory -Path $FB_Dir -Force | Out-Null
    . (Join-Path $PSScriptRoot '..\lib.ps1')

    # Poniedziałek 9 listopada 2026
    $Mon = [datetime]'2026-11-09'

    function Set-TestSchedule([object[]]$Entries) {
        $obj = [ordered]@{ schedule = @($Entries); message = 'Test' }
        [IO.File]::WriteAllText($FB_ConfigPath, (ConvertTo-Json -InputObject $obj -Depth 5))
    }
    function Set-TestList([string[]]$Lines) {
        [IO.File]::WriteAllText($FB_BlocklistPath, (($Lines -join "`r`n") + "`r`n"))
    }
    function Clear-TestState {
        Remove-Item $FB_StatePath, (Join-Path $FB_Dir 'hosts.backup') -ErrorAction SilentlyContinue
        [IO.File]::WriteAllText($FB_HostsPath, "127.0.0.1 localhost`r`n")
    }
    $WorkWeek = @{ days = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri'); from = '09:00'; to = '17:00' }
}

Describe 'ConvertTo-FBTime' {
    It 'czyta <Text> jako <Expected>' -ForEach @(
        @{ Text = '09:00'; Expected = '09:00:00' }
        @{ Text = '9.30';  Expected = '09:30:00' }
        @{ Text = ' 23:59 '; Expected = '23:59:00' }
        @{ Text = '24:00'; Expected = '1.00:00:00' }
    ) {
        (ConvertTo-FBTime $Text).ToString() | Should -Be $Expected
    }

    It 'odrzuca <Text>' -ForEach @(
        @{ Text = '25:00' }, @{ Text = '12:60' }, @{ Text = 'dziewiąta' }, @{ Text = '' }
    ) {
        { ConvertTo-FBTime $Text } | Should -Throw
    }
}

Describe 'ConvertFrom-FBDaysInput' {
    It 'czyta <Text>' -ForEach @(
        @{ Text = 'pon-pt';     Expected = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday' }
        @{ Text = 'sob nd';     Expected = 'Saturday', 'Sunday' }
        @{ Text = 'pon,śr,pt';  Expected = 'Monday', 'Wednesday', 'Friday' }
        @{ Text = 'mon-fri';    Expected = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday' }
        @{ Text = 'pt-pon';     Expected = 'Monday', 'Friday', 'Saturday', 'Sunday' }
        @{ Text = 'Codziennie'; Expected = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' }
    ) {
        ConvertFrom-FBDaysInput $Text | Should -Be $Expected
    }

    It 'odrzuca nieznany dzień' {
        { ConvertFrom-FBDaysInput 'pon,piątek13' } | Should -Throw
    }
}

Describe 'Format-FBDays' {
    It 'zwija <Days> do "<Expected>"' -ForEach @(
        @{ Days = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'; Expected = 'Pon–Pt' }
        @{ Days = 'Monday', 'Wednesday', 'Friday'; Expected = 'Pon, Śr, Pt' }
        @{ Days = 'Monday', 'Tuesday'; Expected = 'Pon, Wt' }
        @{ Days = 'Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'; Expected = 'Codziennie' }
    ) {
        Format-FBDays $Days | Should -Be $Expected
    }
}

Describe 'Format-FBDuration' {
    It '<Span> -> "<Expected>"' -ForEach @(
        @{ Span = '00:00:30'; Expected = 'mniej niż minutę' }
        @{ Span = '00:24:10'; Expected = '25 min' }
        @{ Span = '01:30:00'; Expected = '1 h 30 min' }
        @{ Span = '1.02:00:00'; Expected = '1 d 2 h' }
    ) {
        Format-FBDuration ([TimeSpan]$Span) | Should -Be $Expected
    }
}

Describe 'ConvertTo-FBDomain' {
    It '"<Text>" -> <Expected>' -ForEach @(
        @{ Text = 'https://www.Facebook.com/some/path'; Expected = 'facebook.com' }
        @{ Text = 'x.com   # komentarz'; Expected = 'x.com' }
        @{ Text = 'old.reddit.com:443'; Expected = 'old.reddit.com' }
        @{ Text = '# sam komentarz'; Expected = $null }
        @{ Text = 'to nie domena'; Expected = $null }
    ) {
        ConvertTo-FBDomain $Text | Should -Be $Expected
    }
}

Describe 'Get-FBDomains' {
    It 'dodaje www. i m. tylko do domen głównych' {
        Set-TestList @('# lista', 'facebook.com', 'old.reddit.com', 'facebook.com')
        Get-FBDomains | Should -Be @('facebook.com', 'm.facebook.com', 'old.reddit.com', 'www.facebook.com')
    }
}

Describe 'Get-FBStatus' {
    BeforeEach {
        Clear-TestState
        Set-TestList @('facebook.com')
    }

    It 'w trakcie przedziału: aktywna do jego końca' {
        Set-TestSchedule @($WorkWeek)
        $FB_FakeNow = $Mon.AddHours(14).AddMinutes(47)
        $st = Get-FBStatus
        $st.Active | Should -BeTrue
        $st.Until | Should -Be $Mon.AddHours(17)
        $st.Reason | Should -Be 'harmonogram'
    }

    It 'po przedziale: nieaktywna, następny start jutro rano' {
        Set-TestSchedule @($WorkWeek)
        $FB_FakeNow = $Mon.AddHours(18)
        $st = Get-FBStatus
        $st.Active | Should -BeFalse
        $st.NextStart | Should -Be $Mon.AddDays(1).AddHours(9)
    }

    It 'w piątek wieczorem następny start jest w poniedziałek' {
        Set-TestSchedule @($WorkWeek)
        $FB_FakeNow = $Mon.AddDays(4).AddHours(18)
        (Get-FBStatus).NextStart | Should -Be $Mon.AddDays(7).AddHours(9)
    }

    It 'koniec przedziału jest wyłączny' {
        Set-TestSchedule @($WorkWeek)
        $FB_FakeNow = $Mon.AddHours(17)
        (Get-FBStatus).Active | Should -BeFalse
    }

    Context 'przedział przez północ (pon 22:00–02:00)' {
        BeforeEach { Set-TestSchedule @(@{ days = @('Mon'); from = '22:00'; to = '02:00' }) }

        It 'pon 23:00 - aktywna do wtorku 02:00' {
            $FB_FakeNow = $Mon.AddHours(23)
            (Get-FBStatus).Until | Should -Be $Mon.AddDays(1).AddHours(2)
        }
        It 'wt 01:00 - wciąż aktywna (przedział z poniedziałku)' {
            $FB_FakeNow = $Mon.AddDays(1).AddHours(1)
            (Get-FBStatus).Until | Should -Be $Mon.AddDays(1).AddHours(2)
        }
        It 'pon 01:00 - nieaktywna (niedziela nie ma przedziału)' {
            $FB_FakeNow = $Mon.AddHours(1)
            (Get-FBStatus).Active | Should -BeFalse
        }
    }

    It 'łączy stykające się przedziały' {
        Set-TestSchedule @(
            @{ days = @('Mon'); from = '09:00'; to = '12:00' }
            @{ days = @('Mon'); from = '12:00'; to = '17:00' }
        )
        $FB_FakeNow = $Mon.AddHours(10)
        (Get-FBStatus).Until | Should -Be $Mon.AddHours(17)
    }

    It 'blokada ręczna dłuższa niż harmonogram wygrywa' {
        Set-TestSchedule @($WorkWeek)
        $FB_FakeNow = $Mon.AddHours(15)
        [void](Start-FBManualBlock $Mon.AddHours(19))
        $st = Get-FBStatus
        $st.Until | Should -Be $Mon.AddHours(19)
        $st.Reason | Should -Be 'harmonogram + ręczna'
    }

    It 'blokada ręczna, po której od razu zaczyna się harmonogram, trwa do końca przedziału' {
        Set-TestSchedule @($WorkWeek)
        $FB_FakeNow = $Mon.AddHours(8)
        [void](Start-FBManualBlock $Mon.AddHours(9))
        $st = Get-FBStatus
        $st.Until | Should -Be $Mon.AddHours(17)
        $st.Reason | Should -Be 'ręczna + harmonogram'
    }

    It 'wygasła blokada ręczna jest ignorowana' {
        Set-TestSchedule @()
        $FB_FakeNow = $Mon.AddHours(8)
        [void](Start-FBManualBlock $Mon.AddHours(9))
        $FB_FakeNow = $Mon.AddHours(10)
        (Get-FBStatus).Active | Should -BeFalse
    }
}

Describe 'Start-FBManualBlock' {
    BeforeEach {
        Clear-TestState
        Set-TestList @('facebook.com')
        Set-TestSchedule @()
    }

    It 'nigdy nie skraca trwającej blokady' {
        $FB_FakeNow = $Mon.AddHours(10)
        Start-FBManualBlock $Mon.AddHours(12) | Should -Be $Mon.AddHours(12)
        Start-FBManualBlock $Mon.AddHours(11) | Should -Be $Mon.AddHours(12)
        Get-FBOverrideUntil | Should -Be $Mon.AddHours(12)
    }

    It 'pozwala przedłużyć blokadę' {
        $FB_FakeNow = $Mon.AddHours(10)
        [void](Start-FBManualBlock $Mon.AddHours(12))
        Start-FBManualBlock $Mon.AddHours(14) | Should -Be $Mon.AddHours(14)
    }

    It 'od razu wpisuje sekcję do pliku hosts' {
        $FB_FakeNow = $Mon.AddHours(10)
        [void](Start-FBManualBlock $Mon.AddHours(12))
        Test-FBHostsBlocked | Should -BeTrue
    }
}

Describe 'Remove-FBDomain' {
    BeforeEach {
        Clear-TestState
        Set-TestList @('facebook.com', 'x.com')
    }

    It 'w trakcie blokady odmawia usunięcia' {
        Set-TestSchedule @($WorkWeek)
        $FB_FakeNow = $Mon.AddHours(10)
        { Remove-FBDomain 'x.com' } | Should -Throw
        Get-FBListEntries | Should -Be @('facebook.com', 'x.com')
    }

    It 'poza blokadą usuwa stronę z listy' {
        Set-TestSchedule @($WorkWeek)
        $FB_FakeNow = $Mon.AddHours(20)
        Remove-FBDomain 'x.com'
        Get-FBListEntries | Should -Be @('facebook.com')
    }
}

Describe 'Set-FBHostsBlocked' {
    BeforeEach {
        Clear-TestState
        Set-TestList @('facebook.com')
        [IO.File]::WriteAllText($FB_HostsPath, "# moje wpisy`r`n10.0.0.5 nas.local`r`n")
    }

    It 'dopisuje oznaczoną sekcję i zostawia resztę pliku' {
        Set-FBHostsBlocked $true 'test'
        $h = [IO.File]::ReadAllText($FB_HostsPath)
        $h | Should -Match ([regex]::Escape('10.0.0.5 nas.local'))
        $h | Should -Match ([regex]::Escape($FB_MarkerStart))
        $h | Should -Match '(?m)^0\.0\.0\.0 www\.facebook\.com\r?$'
        $h | Should -Match '(?m)^:: facebook\.com\r?$'
    }

    It 'ponowne włączenie nie dubluje sekcji' {
        Set-FBHostsBlocked $true 'test'
        Set-FBHostsBlocked $true 'test'
        ([regex]::Matches([IO.File]::ReadAllText($FB_HostsPath), [regex]::Escape($FB_MarkerStart))).Count | Should -Be 1
    }

    It 'wyłączenie usuwa sekcję i przywraca resztę pliku' {
        Set-FBHostsBlocked $true 'test'
        Set-FBHostsBlocked $false 'test'
        [IO.File]::ReadAllText($FB_HostsPath) | Should -Be "# moje wpisy`r`n10.0.0.5 nas.local`r`n"
    }

    It 'przed pierwszą zmianą robi kopię pliku hosts' {
        Set-FBHostsBlocked $true 'test'
        [IO.File]::ReadAllText((Join-Path $FB_Dir 'hosts.backup')) | Should -Be "# moje wpisy`r`n10.0.0.5 nas.local`r`n"
    }
}
