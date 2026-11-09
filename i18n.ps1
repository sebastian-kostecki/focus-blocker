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
        # focus.ps1 - wspólne
        'menu.yesNo'           = '[t/N]'
        'menu.removed'         = 'Usunięto.'
        'menu.pageOk'          = 'działa'
        'menu.pageDown'        = 'nie odpowiada'
        'ui.helpMain'          = '↑↓ wybierz · Enter otwórz · 1–4 szybki start · Q wyjście'
        'ui.helpBack'          = 'Esc lub Enter – powrót'
        'ui.helpPick'          = '↑↓ wybierz · Enter potwierdź · Esc wstecz'
        'ui.cancelled'         = 'Anulowano.'

        # focus.ps1 - pulpit
        'st.active'            = 'BLOKADA AKTYWNA'
        'st.activeLine'        = 'do {0} · zostało {1}'
        'st.inactive'          = 'Brak blokady'
        'st.next'              = 'następna: {0} (za {1})'
        'st.reason'            = 'powód: {0}'
        'st.tries'             = 'próby wejścia dziś: {0}'
        'st.page'              = 'strona blokady: {0}'
        'menu.quick'           = 'Szybki start'
        'menu.quickExtend'     = 'Przedłuż o'
        'menu.extend'          = 'Przedłuż blokadę…'
        'menu.start'           = 'Włącz blokadę…'
        'menu.list'            = 'Lista stron'
        'menu.schedule'        = 'Harmonogram'
        'menu.message'         = 'Tekst na stronie blokady'
        'menu.log'             = 'Dziennik'
        'menu.language'        = 'Język / Language'
        'menu.exit'            = 'Wyjście'
        'key.block'            = 'B'
        'key.list'             = 'S'
        'key.schedule'         = 'H'
        'key.message'          = 'K'
        'key.log'              = 'D'
        'key.language'         = 'J'
        'key.exit'             = 'Q'

        # focus.ps1 - blokada ręczna
        'block.howLong'        = '{0} – na jak długo?'
        'block.90min'          = '1,5 h'
        'block.endOfDay'       = 'do końca dnia'
        'block.custom'         = 'inny czas…'
        'block.ask'            = 'Minuty albo godzina końca (np. 90 lub 16:30)'
        'block.badValue'       = 'Nie rozumiem tej wartości.'
        'block.max'            = 'Maksymalnie 7 dni naraz.'
        'block.longer'         = 'Blokada i tak trwa dłużej – do {0}.'
        'block.boxTitle'       = 'Potwierdź blokadę'
        'block.summary'        = 'Blokada potrwa do {0} ({1}).'
        'block.warn'           = 'Nie będzie można jej przerwać ani skrócić.'
        'block.word'           = 'TAK'
        'block.typeToConfirm'  = 'Aby włączyć, wpisz {0} i naciśnij Enter (Esc – anuluj):'
        'block.done'           = 'Blokada aktywna do {0}. Powodzenia!'

        # focus.ps1 - lista stron
        'list.title'           = 'Lista blokowanych stron'
        'list.hint'            = 'Do każdej domeny głównej dochodzi automatycznie www. i m.'
        'list.empty'           = '(pusta)'
        'list.help'            = '↑↓ wybierz · A dodaj · R lub Del usuń · Esc wstecz'
        'list.helpLocked'      = '↑↓ wybierz · A dodaj · usuwanie zablokowane · Esc wstecz'
        'list.more'            = '… jeszcze {0}'
        'list.ask'             = 'Domena (kilka – po przecinku, np. wykop.pl, onet.pl)'
        'list.added'           = 'Dodano: {0}'
        'list.exists'          = 'Już jest na liście: {0}'
        'list.locked'          = 'Blokada trwa – usuwanie stron jest zablokowane.'
        'list.removeAsk'       = 'Usunąć {0}?'
        'list.removed'         = 'Usunięto: {0}'

        # focus.ps1 - harmonogram
        'sched.title'          = 'Harmonogram – w tych godzinach blokada włącza się sama'
        'sched.legend'         = '█ blokada   · wolne   ▼ teraz'
        'sched.empty'          = '(pusty)'
        'sched.help'           = '↑↓ wybierz · A dodaj · R lub Del usuń · Esc wstecz'
        'sched.helpLocked'     = '↑↓ wybierz · A dodaj · usuwanie zablokowane · Esc wstecz'
        'sched.askDays'        = 'Dni (np. pon-pt, sob nd, codziennie)'
        'sched.askFrom'        = 'Od (HH:mm)'
        'sched.askTo'          = 'Do (HH:mm)'
        'sched.same'           = 'Godzina początku i końca są takie same.'
        'sched.nowWarn'        = 'Ten przedział obejmuje bieżącą chwilę – blokada zacznie się od razu i nie da się jej przerwać.'
        'sched.confirm'        = 'Aby dodać, wpisz {0} i naciśnij Enter (Esc – anuluj):'
        'sched.added'          = 'Dodano: {0} {1}–{2}'
        'sched.locked'         = 'Blokada trwa – usuwanie przedziałów jest zablokowane.'

        # focus.ps1 - tekst, dziennik, język
        'msg.title'            = 'Tekst na stronie blokady'
        'msg.current'          = 'Teraz: {0}'
        'msg.hint'             = 'Enter – zatwierdź · Esc – bez zmian · "-" – domyślny'
        'msg.ask'              = 'Nowy tekst'
        'msg.saved'            = 'Zapisano. Zobaczysz go przy następnej próbie wejścia na zablokowaną stronę.'
        'log.title'            = 'Ostatnie wpisy w dzienniku'
        'log.empty'            = '(brak wpisów)'
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
        'menu.removed'         = 'Removed.'
        'menu.pageOk'          = 'running'
        'menu.pageDown'        = 'not responding'
        'ui.helpMain'          = '↑↓ move · Enter open · 1–4 quick start · Q quit'
        'ui.helpBack'          = 'Esc or Enter – back'
        'ui.helpPick'          = '↑↓ move · Enter confirm · Esc back'
        'ui.cancelled'         = 'Cancelled.'

        'st.active'            = 'BLOCK ACTIVE'
        'st.activeLine'        = 'until {0} · {1} left'
        'st.inactive'          = 'No block'
        'st.next'              = 'next: {0} (in {1})'
        'st.reason'            = 'reason: {0}'
        'st.tries'             = 'attempts today: {0}'
        'st.page'              = 'block page: {0}'
        'menu.quick'           = 'Quick start'
        'menu.quickExtend'     = 'Extend by'
        'menu.extend'          = 'Extend the block…'
        'menu.start'           = 'Start a block…'
        'menu.list'            = 'Sites'
        'menu.schedule'        = 'Weekly hours'
        'menu.message'         = 'Block page message'
        'menu.log'             = 'Log'
        'menu.language'        = 'Język / Language'
        'menu.exit'            = 'Exit'
        'key.block'            = 'B'
        'key.list'             = 'S'
        'key.schedule'         = 'H'
        'key.message'          = 'M'
        'key.log'              = 'L'
        'key.language'         = 'J'
        'key.exit'             = 'Q'

        'block.howLong'        = '{0} – for how long?'
        'block.90min'          = '1.5 h'
        'block.endOfDay'       = 'until end of day'
        'block.custom'         = 'custom time…'
        'block.ask'            = 'Minutes or end time (e.g. 90 or 16:30)'
        'block.badValue'       = "I don't understand that value."
        'block.max'            = 'At most 7 days at a time.'
        'block.longer'         = 'The block already lasts longer – until {0}.'
        'block.boxTitle'       = 'Confirm the block'
        'block.summary'        = 'The block will last until {0} ({1}).'
        'block.warn'           = "You won't be able to stop or shorten it."
        'block.word'           = 'YES'
        'block.typeToConfirm'  = 'To start it, type {0} and press Enter (Esc – cancel):'
        'block.done'           = 'Block active until {0}. Good luck!'

        'list.title'           = 'Blocked sites'
        'list.hint'            = 'www. and m. are added to every root domain automatically'
        'list.empty'           = '(empty)'
        'list.help'            = '↑↓ move · A add · R or Del remove · Esc back'
        'list.helpLocked'      = '↑↓ move · A add · removing locked · Esc back'
        'list.more'            = '… {0} more'
        'list.ask'             = 'Domain (several – comma-separated, e.g. reddit.com, youtube.com)'
        'list.added'           = 'Added: {0}'
        'list.exists'          = 'Already on the list: {0}'
        'list.locked'          = 'A block is active – removing sites is locked.'
        'list.removeAsk'       = 'Remove {0}?'
        'list.removed'         = 'Removed: {0}'

        'sched.title'          = 'Schedule – the block turns on by itself at these times'
        'sched.legend'         = '█ blocked   · free   ▼ now'
        'sched.empty'          = '(empty)'
        'sched.help'           = '↑↓ move · A add · R or Del remove · Esc back'
        'sched.helpLocked'     = '↑↓ move · A add · removing locked · Esc back'
        'sched.askDays'        = 'Days (e.g. mon-fri, sat sun, daily)'
        'sched.askFrom'        = 'From (HH:mm)'
        'sched.askTo'          = 'To (HH:mm)'
        'sched.same'           = 'Start and end time are the same.'
        'sched.nowWarn'        = 'This range covers the current time – the block will start right away and cannot be stopped.'
        'sched.confirm'        = 'To add it, type {0} and press Enter (Esc – cancel):'
        'sched.added'          = 'Added: {0} {1}–{2}'
        'sched.locked'         = 'A block is active – removing time ranges is locked.'

        'msg.title'            = 'Block page message'
        'msg.current'          = 'Current: {0}'
        'msg.hint'             = 'Enter – confirm · Esc – keep · "-" – restore default'
        'msg.ask'              = 'New message'
        'msg.saved'            = "Saved. You'll see it the next time you try to open a blocked site."
        'log.title'            = 'Recent log entries'
        'log.empty'            = '(no entries)'
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
