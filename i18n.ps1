# FocusBlocker - teksty interfejsu po polsku i angielsku. Ładowane przez lib.ps1 i instalator.
#
#   T 'klucz'               -> tekst w bieżącym języku ($FB_State.Lang)
#   T 'klucz' arg1 arg2     -> tekst z wypełnionymi {0}, {1}
#
# Brakujący klucz w danym języku zastępuje wersja angielska.

$FB_State = @{ Lang = 'pl' }
$FB_Languages = [ordered]@{ pl = 'Polski'; en = 'English' }

$FB_DayShort = @{
    pl = @{ Monday = 'Pon'; Tuesday = 'Wt'; Wednesday = 'Śr'; Thursday = 'Czw'; Friday = 'Pt'; Saturday = 'Sob'; Sunday = 'Nd' }
    en = @{ Monday = 'Mon'; Tuesday = 'Tue'; Wednesday = 'Wed'; Thursday = 'Thu'; Friday = 'Fri'; Saturday = 'Sat'; Sunday = 'Sun' }
}

$FB_Text = @{
    pl = @{
        'admin.required'       = 'Uruchom PowerShell jako administrator.'
        'default.message'      = 'Ta strona jest teraz zablokowana. Media społecznościowe poczekają – Twoja praca nie.'

        # lib.ps1
        'dur.lessThanMinute'   = 'mniej niż minutę'
        'when.tomorrow'        = 'jutro {0}'
        'when.date'            = 'dd.MM HH:mm'
        'days.every'           = 'Codziennie'
        'reason.schedule'      = 'harmonogram'
        'reason.manual'        = 'ręczna'
        'err.time'             = "Niepoprawna godzina: '{0}' (format HH:mm, np. 09:00)"
        'err.day'              = "Nieznany dzień: '{0}' (np. pon, wt, sr, czw, pt, sob, nd)"
        'err.noDays'           = 'Nie podano dni.'
        'err.missingFile'      = 'Brak pliku {0}'
        'err.notDomain'        = "To nie wygląda na domenę: '{0}'"
        'err.removeDuringBlock' = 'Blokada trwa - nie można teraz usuwać stron z listy.'
        'err.hostsWrite'       = 'Nie udało się zapisać pliku hosts: {0}'
        'log.added'            = 'Dodano do listy: {0}'
        'log.removed'          = 'Usunięto z listy: {0}'
        'log.manual'           = 'Blokada ręczna do {0}'
        'log.on'               = 'Blokada WŁĄCZONA ({0} domen) - {1}'
        'log.off'              = 'Blokada WYŁĄCZONA - {0}'
        'log.auto'             = '{0}, do {1}'
        'log.noBlock'          = 'brak aktywnej blokady'
        'log.uninstall'        = 'odinstalowanie'
        'log.rangeAdded'       = 'Dodano przedział: {0} {1}-{2}'
        'log.rangeRemoved'     = 'Usunięto przedział: {0} {1}-{2}'
        'log.language'         = 'Język interfejsu: {0}'

        # server.ps1
        'log.serverStarted'    = 'Serwer strony blokady uruchomiony na porcie {0}'
        'log.syncError'        = 'Błąd synchronizacji: {0}'
        'log.serverError'      = 'Błąd serwera: {0}'
        'page.blocked'         = 'Zablokowane'
        'page.ended'           = 'Blokada się skończyła'
        'page.thisSite'        = 'Ta strona'
        'page.goTo'            = 'Przejdź do {0}'
        'page.endedInfo'       = 'Możesz już wrócić na tę stronę. Jeśli jeszcze się nie wczytuje, odczekaj minutę.'
        'page.left'            = 'Do końca blokady zostało'
        'page.until'           = 'do {0}'
        'page.tries1'          = 'To Twoja pierwsza próba dzisiaj.'
        'page.triesN'          = 'To już {0}. próba dzisiaj.'
        'page.triesMany'       = 'To już {0}. próba dzisiaj. Może czas na przerwę od ekranu?'
        'page.footer'          = 'Zmiany: menu FocusBlocker w menu Start.'
        'status.title'         = 'Stan blokady'
        'status.on'            = 'Blokada aktywna'
        'status.onHead'        = 'Skup się – strony są zablokowane'
        'status.reason'        = 'Powód: {0}'
        'status.off'           = 'Brak blokady'
        'status.offHead'       = 'Wszystkie strony są dostępne'
        'status.next'          = 'Następna blokada za'
        'status.noSchedule'    = 'Harmonogram jest pusty – blokadę włączysz z menu FocusBlocker.'
        'status.schedule'      = 'Harmonogram'
        'status.scheduleEmpty' = 'Brak przedziałów.'
        'status.sites'         = 'Zablokowane strony ({0})'
        'status.sitesEmpty'    = 'Lista jest pusta.'

        # focus.ps1 - wspólne
        'menu.yesNo'           = '[t/N]'
        'menu.back'            = 'Enter - powrót'
        'menu.backItem'        = '   Enter  powrót'
        'menu.noSuchNumber'    = 'Nie ma takiego numeru.'
        'menu.removed'         = 'Usunięto.'
        'menu.active'          = '  ● BLOKADA AKTYWNA'
        'menu.activeUntil'     = '   do {0}  (zostało {1})'
        'menu.reason'          = '    powód: {0}'
        'menu.inactive'        = '  ○ Brak blokady'
        'menu.next'            = '   następna: {0}'
        'menu.pageOk'          = 'działa'
        'menu.pageDown'        = 'nie odpowiada'
        'menu.summary'         = '    stron na liście: {0} · przedziałów: {1} · strona blokady: {2}'
        'menu.extend'          = 'Przedłuż blokadę'
        'menu.start'           = 'Włącz blokadę teraz'
        'menu.list'            = 'Lista stron'
        'menu.schedule'        = 'Harmonogram'
        'menu.message'         = 'Tekst na stronie blokady'
        'menu.log'             = 'Dziennik'
        'menu.language'        = 'Język / Language'
        'menu.exit'            = 'Wyjście'

        # focus.ps1 - 1. blokada ręczna
        'block.howLong'        = '{0} - na jak długo?'
        'block.90min'          = '1,5 h'
        'block.endOfDay'       = 'do końca dnia'
        'block.custom'         = 'inny czas (liczba minut albo godzina, np. 90 lub 16:30)'
        'block.ask'            = 'Minuty albo godzina końca'
        'block.badValue'       = 'Nie rozumiem tej wartości.'
        'block.max'            = 'Maksymalnie 7 dni naraz.'
        'block.longer'         = 'Blokada i tak trwa dłużej - do {0}.'
        'block.summary'        = '  Blokada potrwa do {0} ({1}).'
        'block.warn'           = '  Nie będzie można jej przerwać ani skrócić.'
        'block.confirm'        = 'Włączyć?'
        'block.done'           = 'Blokada aktywna do {0}. Powodzenia!'

        # focus.ps1 - 2. lista stron
        'list.title'           = '  Lista blokowanych stron'
        'list.hint'            = '  (do każdej domeny głównej dochodzi automatycznie www. i m.)'
        'list.empty'           = '   (pusta)'
        'list.addItem'         = '   d  dodaj'
        'list.removeItem'      = '   u  usuń'
        'list.removeLocked'    = '   u  usuń  (niedostępne podczas blokady)'
        'list.ask'             = 'Domena (kilka - po przecinku, np. wykop.pl, onet.pl)'
        'list.added'           = 'Dodano: {0}'
        'list.exists'          = 'Już jest na liście: {0}'
        'list.locked'          = 'Blokada trwa - usuwanie stron jest zablokowane.'
        'list.askNumber'       = 'Numer strony do usunięcia'
        'list.removed'         = 'Usunięto: {0}'

        # focus.ps1 - 3. harmonogram
        'sched.title'          = '  Harmonogram (w tych godzinach blokada włącza się sama)'
        'sched.empty'          = '   (pusty)'
        'sched.addItem'        = '   d  dodaj przedział'
        'sched.removeItem'     = '   u  usuń przedział'
        'sched.removeLocked'   = '   u  usuń przedział  (niedostępne podczas blokady)'
        'sched.askDays'        = 'Dni (np. pon-pt, sob nd, codziennie)'
        'sched.askFrom'        = 'Od (HH:mm)'
        'sched.askTo'          = 'Do (HH:mm)'
        'sched.same'           = 'Godzina początku i końca są takie same.'
        'sched.nowWarn'        = '  Ten przedział obejmuje bieżącą chwilę - blokada zacznie się od razu i nie da się jej przerwać.'
        'sched.confirm'        = 'Dodać mimo to?'
        'sched.added'          = 'Dodano: {0} {1}–{2}'
        'sched.locked'         = 'Blokada trwa - usuwanie przedziałów jest zablokowane.'
        'sched.askNumber'      = 'Numer przedziału do usunięcia'

        # focus.ps1 - 4. tekst, 5. dziennik, 6. język
        'msg.title'            = '  Tekst na stronie blokady'
        'msg.current'          = '  Teraz: {0}'
        'msg.hint'             = '  Wpisz nowy tekst. Enter - bez zmian, "-" - przywróć domyślny.'
        'msg.ask'              = 'Nowy tekst'
        'msg.saved'            = 'Zapisano. Zobaczysz go przy następnej próbie wejścia na zablokowaną stronę.'
        'log.title'            = '  Ostatnie wpisy w dzienniku'
        'log.empty'            = '   (brak wpisów)'
        'lang.saved'           = 'Język interfejsu: {0}.'

        # blocker.ps1
        'cli.minutes'          = 'Podaj -Minutes większe od zera.'
        'cli.on'               = 'Blokada aktywna do {0}.'
        'cli.statusOn'         = 'Blokada AKTYWNA ({0}) do {1}'
        'cli.noneScheduled'    = 'brak w harmonogramie'
        'cli.statusOff'        = 'Brak blokady. Następna: {0}'
        'cli.hosts'            = 'Plik hosts zablokowany: {0}'
        'cli.domains'          = 'Domen: {0}'

        # install.ps1 / uninstall.ps1
        'inst.activeBlock'     = 'Blokada trwa do {0}. Aktualizacja będzie możliwa po jej zakończeniu.'
        'inst.taskDesc'        = 'Blokuje rozpraszające strony (plik hosts) wg harmonogramu. Pliki: {0}'
        'inst.pageDesc'        = 'Lokalna strona z komunikatem FocusBlocker (http://127.0.0.1:{0})'
        'inst.shortcutDesc'    = 'FocusBlocker – blokada rozpraszających stron'
        'inst.done'            = 'FocusBlocker zainstalowany w {0}'
        'inst.language'        = 'Język interfejsu: {0} (zmienisz go w menu, opcja 6).'
        'inst.lastStep'        = 'Ostatni krok – rozszerzenie z ładną stroną blokady (Chrome lub Edge):'
        'inst.step1'           = '  1. Otwórz chrome://extensions (w Edge: edge://extensions)'
        'inst.step2'           = '  2. Włącz "Tryb dewelopera"'
        'inst.step3'           = '  3. "Załaduj rozpakowane" i wskaż folder:'
        'inst.menu'            = 'Menu otworzysz skrótem "FocusBlocker" w menu Start.'
        'uninst.activeBlock'   = 'Blokada trwa do {0}. Odinstalowanie będzie możliwe po jej zakończeniu.'
        'uninst.done'          = 'FocusBlocker odinstalowany.'
        'uninst.extension'     = 'Rozszerzenie usuń ręcznie w chrome://extensions (lub edge://extensions).'
    }

    en = @{
        'admin.required'       = 'Run PowerShell as administrator.'
        'default.message'      = "This site is blocked right now. Social media can wait – your work can't."

        'dur.lessThanMinute'   = 'less than a minute'
        'when.tomorrow'        = 'tomorrow {0}'
        'when.date'            = 'MMM d, HH:mm'
        'days.every'           = 'Every day'
        'reason.schedule'      = 'schedule'
        'reason.manual'        = 'manual'
        'err.time'             = "Invalid time: '{0}' (use HH:mm, e.g. 09:00)"
        'err.day'              = "Unknown day: '{0}' (e.g. mon, tue, wed, thu, fri, sat, sun)"
        'err.noDays'           = 'No days given.'
        'err.missingFile'      = 'Missing file {0}'
        'err.notDomain'        = "That doesn't look like a domain: '{0}'"
        'err.removeDuringBlock' = "A block is active - sites can't be removed right now."
        'err.hostsWrite'       = "Couldn't write the hosts file: {0}"
        'log.added'            = 'Added to the list: {0}'
        'log.removed'          = 'Removed from the list: {0}'
        'log.manual'           = 'Manual block until {0}'
        'log.on'               = 'Block ON ({0} domains) - {1}'
        'log.off'              = 'Block OFF - {0}'
        'log.auto'             = '{0}, until {1}'
        'log.noBlock'          = 'no active block'
        'log.uninstall'        = 'uninstall'
        'log.rangeAdded'       = 'Added time range: {0} {1}-{2}'
        'log.rangeRemoved'     = 'Removed time range: {0} {1}-{2}'
        'log.language'         = 'Interface language: {0}'

        'log.serverStarted'    = 'Block page server started on port {0}'
        'log.syncError'        = 'Sync error: {0}'
        'log.serverError'      = 'Server error: {0}'
        'page.blocked'         = 'Blocked'
        'page.ended'           = 'The block is over'
        'page.thisSite'        = 'This site'
        'page.goTo'            = 'Go to {0}'
        'page.endedInfo'       = "You can go back to this site now. If it still doesn't load, give it a minute."
        'page.left'            = 'Time left'
        'page.until'           = 'until {0}'
        'page.tries1'          = 'This is your first attempt today.'
        'page.triesN'          = 'That makes {0} attempts today.'
        'page.triesMany'       = 'That makes {0} attempts today. Maybe time for a break from the screen?'
        'page.footer'          = 'To change settings, open FocusBlocker from the Start menu.'
        'status.title'         = 'Block status'
        'status.on'            = 'Block active'
        'status.onHead'        = 'Stay focused – sites are blocked'
        'status.reason'        = 'Reason: {0}'
        'status.off'           = 'No block'
        'status.offHead'       = 'All sites are available'
        'status.next'          = 'Next block starts in'
        'status.noSchedule'    = 'The schedule is empty – start a block from the FocusBlocker menu.'
        'status.schedule'      = 'Schedule'
        'status.scheduleEmpty' = 'No time ranges.'
        'status.sites'         = 'Blocked sites ({0})'
        'status.sitesEmpty'    = 'The list is empty.'

        'menu.yesNo'           = '[y/N]'
        'menu.back'            = 'Enter - back'
        'menu.backItem'        = '   Enter  back'
        'menu.noSuchNumber'    = 'No such number.'
        'menu.removed'         = 'Removed.'
        'menu.active'          = '  ● BLOCK ACTIVE'
        'menu.activeUntil'     = '   until {0}  ({1} left)'
        'menu.reason'          = '    reason: {0}'
        'menu.inactive'        = '  ○ No block'
        'menu.next'            = '   next: {0}'
        'menu.pageOk'          = 'running'
        'menu.pageDown'        = 'not responding'
        'menu.summary'         = '    sites: {0} · time ranges: {1} · block page: {2}'
        'menu.extend'          = 'Extend the block'
        'menu.start'           = 'Start a block now'
        'menu.list'            = 'Sites'
        'menu.schedule'        = 'Schedule'
        'menu.message'         = 'Block page message'
        'menu.log'             = 'Log'
        'menu.language'        = 'Język / Language'
        'menu.exit'            = 'Exit'

        'block.howLong'        = '{0} - for how long?'
        'block.90min'          = '1.5 h'
        'block.endOfDay'       = 'until end of day'
        'block.custom'         = 'custom (minutes or an end time, e.g. 90 or 16:30)'
        'block.ask'            = 'Minutes or end time'
        'block.badValue'       = "I don't understand that value."
        'block.max'            = 'At most 7 days at a time.'
        'block.longer'         = 'The block already lasts longer - until {0}.'
        'block.summary'        = '  The block will last until {0} ({1}).'
        'block.warn'           = "  You won't be able to stop or shorten it."
        'block.confirm'        = 'Start it?'
        'block.done'           = 'Block active until {0}. Good luck!'

        'list.title'           = '  Blocked sites'
        'list.hint'            = '  (www. and m. are added to every root domain automatically)'
        'list.empty'           = '   (empty)'
        'list.addItem'         = '   a  add'
        'list.removeItem'      = '   r  remove'
        'list.removeLocked'    = '   r  remove  (not available during a block)'
        'list.ask'             = 'Domain (several - comma-separated, e.g. reddit.com, youtube.com)'
        'list.added'           = 'Added: {0}'
        'list.exists'          = 'Already on the list: {0}'
        'list.locked'          = 'A block is active - removing sites is locked.'
        'list.askNumber'       = 'Number of the site to remove'
        'list.removed'         = 'Removed: {0}'

        'sched.title'          = '  Schedule (the block turns on by itself at these times)'
        'sched.empty'          = '   (empty)'
        'sched.addItem'        = '   a  add a time range'
        'sched.removeItem'     = '   r  remove a time range'
        'sched.removeLocked'   = '   r  remove a time range  (not available during a block)'
        'sched.askDays'        = 'Days (e.g. mon-fri, sat sun, daily)'
        'sched.askFrom'        = 'From (HH:mm)'
        'sched.askTo'          = 'To (HH:mm)'
        'sched.same'           = 'Start and end time are the same.'
        'sched.nowWarn'        = '  This range covers the current time - the block will start right away and cannot be stopped.'
        'sched.confirm'        = 'Add it anyway?'
        'sched.added'          = 'Added: {0} {1}–{2}'
        'sched.locked'         = 'A block is active - removing time ranges is locked.'
        'sched.askNumber'      = 'Number of the time range to remove'

        'msg.title'            = '  Block page message'
        'msg.current'          = '  Current: {0}'
        'msg.hint'             = '  Type a new message. Enter - keep it, "-" - restore the default.'
        'msg.ask'              = 'New message'
        'msg.saved'            = "Saved. You'll see it the next time you try to open a blocked site."
        'log.title'            = '  Recent log entries'
        'log.empty'            = '   (no entries)'
        'lang.saved'           = 'Interface language: {0}.'

        'cli.minutes'          = '-Minutes must be greater than zero.'
        'cli.on'               = 'Block active until {0}.'
        'cli.statusOn'         = 'Block ACTIVE ({0}) until {1}'
        'cli.noneScheduled'    = 'none scheduled'
        'cli.statusOff'        = 'No block. Next: {0}'
        'cli.hosts'            = 'Hosts file blocked: {0}'
        'cli.domains'          = 'Domains: {0}'

        'inst.activeBlock'     = 'A block is active until {0}. You can update once it ends.'
        'inst.taskDesc'        = 'Blocks distracting websites (hosts file) on a schedule. Files: {0}'
        'inst.pageDesc'        = 'FocusBlocker local block page (http://127.0.0.1:{0})'
        'inst.shortcutDesc'    = 'FocusBlocker – block distracting websites'
        'inst.done'            = 'FocusBlocker installed in {0}'
        'inst.language'        = 'Interface language: {0} (change it in the menu, option 6).'
        'inst.lastStep'        = 'Last step – the extension with the friendly block page (Chrome or Edge):'
        'inst.step1'           = '  1. Open chrome://extensions (Edge: edge://extensions)'
        'inst.step2'           = '  2. Turn on "Developer mode"'
        'inst.step3'           = '  3. Click "Load unpacked" and select the folder:'
        'inst.menu'            = 'Open the menu with the "FocusBlocker" shortcut in the Start menu.'
        'uninst.activeBlock'   = 'A block is active until {0}. You can uninstall once it ends.'
        'uninst.done'          = 'FocusBlocker uninstalled.'
        'uninst.extension'     = 'Remove the extension manually in chrome://extensions (or edge://extensions).'
    }
}

# Język systemu osoby, która uruchamia skrypt (instalator zapisuje go w config.json,
# bo zadania działające jako SYSTEM mają często inny język niż użytkownik)
function Get-FBSystemLanguage {
    if ((Get-UICulture).TwoLetterISOLanguageName -eq 'pl' -or (Get-Culture).TwoLetterISOLanguageName -eq 'pl') { return 'pl' }
    return 'en'
}

function T([string]$Key) {
    $table = $FB_Text[$FB_State.Lang]
    $s = if ($table -and $table.ContainsKey($Key)) { $table[$Key] }
         elseif ($FB_Text.en.ContainsKey($Key)) { $FB_Text.en[$Key] }
         else { $Key }
    if ($args.Count) { return ($s -f $args) }
    return $s
}
