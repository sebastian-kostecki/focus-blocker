#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
# Dymne testy menu w terminalu (focus.ps1) na sztucznej kolejce klawiszy.
# Wszystko dzieje się w katalogu tymczasowym Pestera - prawdziwy plik hosts nie jest ruszany.

BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'

    # Uruchamia menu z podaną kolejką klawiszy; zwraca cały wypisany tekst.
    # Zwykły tekst wpisujemy jako "txt:TAK" (spacja = "_").
    function Invoke-Menu {
        param([string]$Keys, [string]$Language = 'en', [string]$Now = '2026-11-09T18:30:00', [object[]]$Schedule = @())
        $FB_Dir = Join-Path $TestDrive 'fb'
        New-Item -ItemType Directory -Path $FB_Dir -Force | Out-Null
        Remove-Item (Join-Path $FB_Dir 'state.json') -ErrorAction SilentlyContinue
        $FB_HostsPath = Join-Path $FB_Dir 'hosts'
        [IO.File]::WriteAllText($FB_HostsPath, "127.0.0.1 localhost`r`n")
        [IO.File]::WriteAllText((Join-Path $FB_Dir 'blocklist.txt'), "facebook.com`r`nreddit.com`r`n")
        $cfg = [ordered]@{ language = $Language; schedule = @($Schedule); message = '' }
        [IO.File]::WriteAllText((Join-Path $FB_Dir 'config.json'), (ConvertTo-Json -InputObject $cfg -Depth 5))
        $FB_NoClear = $true; $FB_FakeAdmin = $true; $FB_FakeNow = $Now; $FB_Port = 47999
        $FB_KeyQueue = New-Object 'System.Collections.Generic.Queue[string]'
        foreach ($tok in ($Keys -split ' ')) {
            if ($tok -like 'txt:*') { foreach ($ch in $tok.Substring(4).Replace('_', ' ').ToCharArray()) { $FB_KeyQueue.Enqueue([string]$ch) } }
            elseif ($tok) { $FB_KeyQueue.Enqueue($tok) }
        }
        $out = & { . (Join-Path $script:Root 'focus.ps1') } *>&1 | Out-String
        return $out
    }
    $script:WorkWeek = @{ days = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri'); from = '09:00'; to = '17:00' }
}

Describe 'Pulpit' {
    It 'pokazuje brak blokady, szybki start i menu (EN)' {
        $o = Invoke-Menu 'Q'
        $o | Should -Match 'No block'
        $o | Should -Match 'Quick start'
        $o | Should -Match 'Start a block'
    }

    It 'pokazuje aktywną blokadę z paskiem postępu (PL)' {
        $o = Invoke-Menu 'Q' -Language pl -Now '2026-11-09T14:47:00' -Schedule @($script:WorkWeek)
        $o | Should -Match 'BLOKADA AKTYWNA'
        $o | Should -Match 'do 17:00'
        $o | Should -Match '72%'
        $o | Should -Match 'Przedłuż o'
    }

    It 'nie zostawia surowych kluczy tłumaczeń na ekranie: <Lang>' -ForEach @(@{ Lang = 'pl' }, @{ Lang = 'en' }) {
        $msg = if ($Lang -eq 'pl') { 'K' } else { 'M' }
        $log = if ($Lang -eq 'pl') { 'D' } else { 'L' }
        $o = Invoke-Menu "S Escape H Escape B Escape $msg Escape $log Enter J Escape Q" -Language $Lang
        $o | Should -Not -Match '\b(menu|block|list|sched|msg|log|st|ui|key)\.[a-zA-Z0-9]+\b'
    }
}

Describe 'Szybki start' {
    It 'włącza blokadę dopiero po wpisaniu słowa potwierdzającego' {
        $o = Invoke-Menu '1 txt:YES Enter Q'
        $o | Should -Match 'Block active until 18:55'
        (Get-Content (Join-Path $TestDrive 'fb\state.json') -Raw) | Should -Match '2026-11-09T18:55:00'
    }

    It 'dla "TAK" też działa niezależnie od języka' {
        $null = Invoke-Menu '1 txt:TAK Enter Q'
        Test-Path (Join-Path $TestDrive 'fb\state.json') | Should -BeTrue
    }

    It 'inne słowo albo Esc anuluje' {
        $o = Invoke-Menu '1 txt:nie Enter Q'
        $o | Should -Match 'Cancelled'
        Test-Path (Join-Path $TestDrive 'fb\state.json') | Should -BeFalse
        $null = Invoke-Menu '2 txt:YE Escape Q'
        Test-Path (Join-Path $TestDrive 'fb\state.json') | Should -BeFalse
    }

    It 'przy trwającej blokadzie przedłuża ją o wybrany czas' {
        $null = Invoke-Menu '2 txt:YES Enter Q' -Now '2026-11-09T14:47:00' -Schedule @($script:WorkWeek)
        (Get-Content (Join-Path $TestDrive 'fb\state.json') -Raw) | Should -Match '2026-11-09T17:50:00'
    }
}

Describe 'Lista stron' {
    It 'dodaje kilka domen naraz' {
        $o = Invoke-Menu 'S A txt:wykop.pl,_onet.pl Enter Q'
        $o | Should -Match 'Added: wykop.pl, onet.pl'
        (Get-Content (Join-Path $TestDrive 'fb\blocklist.txt')) | Should -Contain 'onet.pl'
    }

    It 'usuwa zaznaczoną stronę po potwierdzeniu' {
        $null = Invoke-Menu 'S DownArrow R y Escape Q'
        $list = Get-Content (Join-Path $TestDrive 'fb\blocklist.txt')
        $list | Should -Contain 'facebook.com'
        $list | Should -Not -Contain 'reddit.com'
    }

    It 'nie usuwa nic podczas blokady' {
        $o = Invoke-Menu 'S R y Escape Q' -Now '2026-11-09T14:47:00' -Schedule @($script:WorkWeek)
        $o | Should -Match 'removing sites is locked'
        (Get-Content (Join-Path $TestDrive 'fb\blocklist.txt')) | Should -Contain 'facebook.com'
    }
}

Describe 'Harmonogram' {
    It 'rysuje siatkę tygodnia i dodaje przedział' {
        $o = Invoke-Menu 'H A txt:sat_sun Enter txt:10:00 Enter txt:12:00 Enter Escape Q'
        $o | Should -Match 'Sat, Sun\s+10:00–12:00'
        $o | Should -Match 'Mon  ·+'
        $cfg = Get-Content (Join-Path $TestDrive 'fb\config.json') -Raw | ConvertFrom-Json
        @($cfg.schedule).Count | Should -Be 1
    }

    It 'przedział obejmujący "teraz" wymaga potwierdzenia słowem' {
        $null = Invoke-Menu 'H A txt:daily Enter txt:00:00 Enter txt:23:00 Enter txt:nie Enter Escape Q'
        $cfg = Get-Content (Join-Path $TestDrive 'fb\config.json') -Raw | ConvertFrom-Json
        @($cfg.schedule).Count | Should -Be 0
        $null = Invoke-Menu 'H A txt:daily Enter txt:00:00 Enter txt:23:00 Enter txt:YES Enter Escape Q'
        $cfg = Get-Content (Join-Path $TestDrive 'fb\config.json') -Raw | ConvertFrom-Json
        @($cfg.schedule).Count | Should -Be 1
    }

    It 'usuwa przedział po potwierdzeniu, ale nie podczas blokady' {
        $null = Invoke-Menu 'H R y Escape Q' -Schedule @($script:WorkWeek)
        $cfg = Get-Content (Join-Path $TestDrive 'fb\config.json') -Raw | ConvertFrom-Json
        @($cfg.schedule).Count | Should -Be 0
        $null = Invoke-Menu 'H R y Escape Q' -Now '2026-11-09T14:47:00' -Schedule @($script:WorkWeek)
        $cfg = Get-Content (Join-Path $TestDrive 'fb\config.json') -Raw | ConvertFrom-Json
        @($cfg.schedule).Count | Should -Be 1
    }
}

Describe 'Język i komunikat' {
    It 'przełącza język i zapamiętuje go' {
        $null = Invoke-Menu 'J 1 Q' -Language en
        (Get-Content (Join-Path $TestDrive 'fb\config.json') -Raw | ConvertFrom-Json).language | Should -Be 'pl'
    }

    It 'zapisuje własny komunikat, "-" przywraca domyślny' {
        $null = Invoke-Menu 'M txt:Do_roboty! Enter Q'
        (Get-Content (Join-Path $TestDrive 'fb\config.json') -Raw | ConvertFrom-Json).message | Should -Be 'Do roboty!'
        $null = Invoke-Menu 'M txt:- Enter Q'
        (Get-Content (Join-Path $TestDrive 'fb\config.json') -Raw | ConvertFrom-Json).message | Should -BeNullOrEmpty
    }
}
