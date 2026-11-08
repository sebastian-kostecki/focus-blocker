# FocusBlocker

Blokuje rozpraszające strony (Facebook, Instagram, X, TikTok, Reddit…) w godzinach pracy.
Działa na Windows 10/11, nie wymaga instalowania żadnych programów – korzysta z wbudowanego
PowerShella, pliku `hosts` i Harmonogramu zadań.

Najważniejsza zasada: **trwającej blokady nie da się wyłączyć ani skrócić** – ani z menu,
ani przez ponowną instalację, ani przez odinstalowanie. Można ją tylko przedłużyć.

## Jak to działa

```
 Harmonogram zadań                      C:\Windows\System32\drivers\etc\hosts
 ┌──────────────────────┐   co minutę   ┌───────────────────────────────────────┐
 │ FocusBlocker         │──────────────▶│ # >>> FocusBlocker START               │
 │  (blocker.ps1)       │  dopisuje lub │ 0.0.0.0 facebook.com                   │
 └──────────────────────┘  usuwa sekcję │ 0.0.0.0 instagram.com  ...             │
          ▲                             │ # <<< FocusBlocker END                 │
          │ czyta                       └───────────────────────────────────────┘
 ┌──────────────────────┐                          │ facebook.com -> 0.0.0.0
 │ config.json          │ harmonogram, tekst       ▼ (połączenie się nie udaje)
 │ blocklist.txt        │ lista stron      ┌──────────────────────────────┐
 │ state.json           │ blokada ręczna   │ Przeglądarka + rozszerzenie  │
 └──────────────────────┘                  │ FocusBlocker przekierowuje na│
          ▲                                │ stronę z komunikatem         │
          │ zmienia                        └──────────────┬───────────────┘
 ┌──────────────────────┐                                 │ /status, /blocked
 │ focus.ps1 (menu)     │                  ┌──────────────▼───────────────┐
 └──────────────────────┘                  │ FocusBlocker-Page            │
                                           │ server.ps1 – 127.0.0.1:47615 │
                                           └──────────────────────────────┘
```

1. **Plik `hosts`** – Windows najpierw sprawdza ten plik, zanim zapyta serwer DNS. Wpis
   `0.0.0.0 facebook.com` sprawia, że komputer „myśli”, że Facebook jest pod adresem, z którym
   nie da się połączyć. Działa to we wszystkich przeglądarkach i aplikacjach naraz.
2. **Zadanie „FocusBlocker”** uruchamia się co minutę (i przy starcie Windows) jako konto SYSTEM.
   Sprawdza, czy teraz trwa blokada (harmonogram albo blokada ręczna), i dopisuje lub usuwa
   sekcję FocusBlockera w pliku `hosts`. Resztę pliku zostawia w spokoju. Jeśli ktoś ręcznie
   usunie wpisy, wrócą w ciągu minuty.
3. **Zadanie „FocusBlocker-Page”** uruchamia mały lokalny serwer WWW (`server.ps1`) dostępny
   tylko z tego komputera pod `http://127.0.0.1:47615`. Pokazuje stronę z komunikatem i podaje
   stan blokady rozszerzeniu. Co 30 s dodatkowo pilnuje pliku `hosts`.
4. **Rozszerzenie przeglądarki** (Chrome/Edge) zamiast błędu połączenia pokazuje stronę
   z Twoim tekstem, czasem do końca blokady i licznikiem prób. Zamienia też karty, które były
   otwarte w chwili rozpoczęcia blokady.

### Dlaczego potrzebne jest rozszerzenie?

Prawie wszystkie serwisy działają po HTTPS. Sam plik `hosts` nie może podsunąć przeglądarce
własnej strony zamiast facebook.com, bo przeglądarka zażąda certyfikatu Facebooka – skończy
się błędem bezpieczeństwa. Jedyną alternatywą byłoby zainstalowanie własnego certyfikatu
głównego (CA) w systemie, co osłabia bezpieczeństwo całego komputera. Rozszerzenie robi to
samo bezpiecznie. **Blokada działa także bez rozszerzenia** – wtedy zobaczysz zwykły błąd
połączenia zamiast komunikatu.

## Instalacja

1. Rozpakuj paczkę, np. do `Dokumenty\FocusBlocker`.
2. Otwórz **PowerShell jako administrator** (Start → wpisz „PowerShell” → „Uruchom jako administrator”):

   ```powershell
   cd "$HOME\Documents\FocusBlocker"
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

3. Zainstaluj rozszerzenie:
   - otwórz `chrome://extensions` (w Edge: `edge://extensions`),
   - włącz **Tryb dewelopera**,
   - kliknij **Załaduj rozpakowane** i wskaż folder `C:\ProgramData\FocusBlocker\extension`.

Gotowe. W menu Start pojawi się skrót **FocusBlocker**.

## Obsługa – menu w terminalu

Uruchom skrót **FocusBlocker** z menu Start (Windows zapyta o uprawnienia administratora).

```
  FocusBlocker
  ──────────────────────────────────────────────────
  ● BLOKADA AKTYWNA   do 17:00  (zostało 2 h 13 min)
    powód: harmonogram
    stron na liście: 12 · przedziałów: 1 · strona blokady: działa
  ──────────────────────────────────────────────────

   1  Przedłuż blokadę
   2  Lista stron
   3  Harmonogram
   4  Tekst na stronie blokady
   5  Dziennik
   0  Wyjście
```

| Opcja | Co robi | W trakcie blokady |
|---|---|---|
| 1 | Blokada od razu: 25 min, 50 min, 1,5 h, 2 h, do końca dnia albo własny czas (np. `90` lub `16:30`) | tylko przedłużenie |
| 2 | Dodawanie i usuwanie stron (można dodać kilka po przecinku) | tylko dodawanie |
| 3 | Dodawanie i usuwanie przedziałów harmonogramu, np. `pon-pt` 09:00–12:00 | tylko dodawanie |
| 4 | Tekst wyświetlany na stronie blokady | tak |
| 5 | Ostatnie wpisy w dzienniku | tak |

Dni w harmonogramie wpisuje się po polsku lub angielsku: `pon-pt`, `pon,sr,pt`, `sob nd`,
`codziennie`, `mon-fri`. Przedział może przechodzić przez północ (np. 22:00–02:00).

## Pliki (`C:\ProgramData\FocusBlocker`)

| Plik | Zawartość |
|---|---|
| `focus.ps1` | menu w terminalu |
| `blocker.ps1` | wersja dla Harmonogramu zadań (`-Mode Auto`, `-Mode On -Minutes 60`, `-Mode Status`) |
| `server.ps1` | lokalna strona blokady |
| `lib.ps1` | wspólne funkcje |
| `blocklist.txt` | lista stron (jedna domena na linię, `#` = komentarz) |
| `config.json` | harmonogram i tekst komunikatu |
| `state.json` | koniec blokady ręcznej |
| `blocker.log` | dziennik |
| `hosts.backup` | kopia pliku `hosts` sprzed pierwszej zmiany |
| `extension\` | rozszerzenie przeglądarki |

Zapisywać w tym folderze może tylko administrator.

## Aktualizacja i odinstalowanie

- **Aktualizacja:** uruchom `install.ps1` z nowej wersji. Lista stron i harmonogram zostaną zachowane.
- **Odinstalowanie** (jako administrator):

  ```powershell
  powershell -ExecutionPolicy Bypass -File "C:\ProgramData\FocusBlocker\uninstall.ps1"
  ```

  Rozszerzenie usuń ręcznie w `chrome://extensions`.

Obie operacje odmówią działania, dopóki trwa blokada.

## Uczciwie o ograniczeniach

- Jesteś administratorem tego komputera, więc zdeterminowana osoba zawsze może ręcznie usunąć
  zadania z Harmonogramu zadań. FocusBlocker nie jest więzieniem – ma sprawić, że ominięcie
  blokady wymaga tyle wysiłku, że łatwiej wrócić do pracy.
- Blokada nie działa przez VPN ani proxy z własnym DNS.
- Plik `hosts` nie obsługuje symboli wieloznacznych. Do domen głównych automatycznie dochodzą
  `www.` i `m.`; inne subdomeny dopisz osobno (rozszerzenie i tak łapie wszystkie subdomeny).
- Rozszerzenie działa w Chrome i Edge. W Firefoksie blokada działa, ale bez strony z komunikatem.
