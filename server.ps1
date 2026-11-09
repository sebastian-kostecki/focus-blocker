#Requires -Version 5.1
<#
.SYNOPSIS
    FocusBlocker - lokalny serwer strony blokady (http://127.0.0.1:47615).
    Uruchamiany przy starcie systemu przez zadanie "FocusBlocker-Page".

    /status            stan blokady w JSON (czyta go rozszerzenie przeglądarki)
    /blocked?site=...  strona z komunikatem, na którą rozszerzenie przekierowuje
    /                  podgląd stanu

    Przy okazji co 30 s pilnuje, żeby plik hosts zgadzał się z harmonogramem
    (druga linia obrony obok zadania uruchamianego co minutę).
#>
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib.ps1"

$attempts = @{}   # liczba prób wejścia na zablokowane strony, per dzień

function ConvertTo-HtmlText([string]$Text) { return [System.Net.WebUtility]::HtmlEncode($Text) }

function Send-Response($Ctx, [int]$Code, [string]$Type, [string]$Body) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
    $r = $Ctx.Response
    $r.StatusCode = $Code
    $r.ContentType = "$Type; charset=utf-8"
    $r.Headers['Cache-Control'] = 'no-store'
    $r.ContentLength64 = $bytes.Length
    $r.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Get-StatusJson {
    $st = Get-FBStatus
    $obj = [ordered]@{
        active  = $st.Active
        reason  = $st.Reason
        until   = if ($st.Until) { $st.Until.ToString('s', $FB_Inv) } else { $null }
        domains = [string[]]@($st.Domains | ForEach-Object { $_ -replace '^(www|m)\.', '' } | Sort-Object -Unique)
    }
    return (ConvertTo-Json -InputObject $obj -Compress)
}

# ------------------------------------------------------------------ wygląd stron

$Logo = '<svg viewBox="0 0 128 128" aria-hidden="true"><defs><linearGradient id="fbg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f97316"/><stop offset="1" stop-color="#c2410c"/></linearGradient></defs><rect x="4" y="4" width="120" height="120" rx="28" fill="url(#fbg)"/><circle cx="64" cy="64" r="35" fill="none" stroke="#fff" stroke-width="12"/><circle cx="64" cy="64" r="13" fill="#fff"/></svg>'
$Favicon = 'data:image/svg+xml,' + [uri]::EscapeDataString(($Logo -replace '<svg ', '<svg xmlns="http://www.w3.org/2000/svg" '))

$PageCss = @'
  :root { --bg:#f6f5f2; --card:#fff; --text:#1d1d1f; --muted:#6b6b70; --accent:#c2410c; --on-accent:#fff;
          --accent-soft:#fff3eb; --line:#e7e5e0; --ok:#15803d; --ok-soft:#eaf6ee; }
  @media (prefers-color-scheme: dark) {
    :root { --bg:#141416; --card:#1d1d20; --text:#ececee; --muted:#9a9aa2; --accent:#fb923c; --on-accent:#1d1d20;
            --accent-soft:#2b2019; --line:#2c2c31; --ok:#4ade80; --ok-soft:#16261c; }
  }
  * { box-sizing:border-box }
  body { margin:0; min-height:100vh; display:grid; place-items:center; padding:24px 16px;
         background:var(--bg); color:var(--text); font:16px/1.55 "Segoe UI",system-ui,sans-serif; }
  main { width:100%; max-width:560px; background:var(--card); border:1px solid var(--line);
         border-radius:16px; padding:36px; box-shadow:0 1px 2px rgba(0,0,0,.04), 0 12px 32px rgba(0,0,0,.05); }
  @media (max-width:480px) { main { padding:28px 22px } }
  .brand { display:flex; align-items:center; gap:10px; margin-bottom:22px; font-size:13px; letter-spacing:.06em;
           text-transform:uppercase; color:var(--accent); font-weight:600 }
  .brand svg { width:26px; height:26px; flex:none }
  h1 { font-size:28px; line-height:1.25; margin:0 0 4px; font-weight:650 }
  h2 { font-size:13px; letter-spacing:.06em; text-transform:uppercase; color:var(--muted); font-weight:600; margin:28px 0 10px }
  .site { color:var(--muted); margin:0 0 24px; word-break:break-all }
  .msg { font-size:20px; line-height:1.5; margin:0 0 24px; padding-left:16px; border-left:3px solid var(--accent) }
  .countdown { background:var(--accent-soft); border-radius:12px; padding:14px 20px 16px; margin:0 0 14px;
               display:flex; flex-wrap:wrap; align-items:baseline; justify-content:space-between; gap:0 16px }
  .countdown .label { width:100%; color:var(--muted); font-size:14px }
  .timer { font-size:36px; line-height:1.2; font-weight:650; color:var(--accent); font-variant-numeric:tabular-nums }
  .until { color:var(--muted) }
  .until b { color:var(--text) }
  .tries { margin:0; color:var(--muted); font-size:14px }
  .ended { display:none }
  .ended p { margin:0 }
  .done .ended { display:block }
  .done .countdown, .done .tries, .done .msg { display:none }
  h1 + .countdown { margin-top:20px }
  .btn { display:inline-block; margin-top:14px; padding:9px 18px; border-radius:8px; background:var(--accent);
         color:var(--on-accent); text-decoration:none; font-weight:600 }
  .btn:hover { filter:brightness(1.08) }
  .pill { display:inline-flex; align-items:center; gap:8px; padding:3px 12px; border-radius:999px;
          font-size:14px; font-weight:600; margin-bottom:14px }
  .pill::before { content:""; width:8px; height:8px; border-radius:50%; background:currentColor }
  .pill.on { background:var(--accent-soft); color:var(--accent) }
  .pill.off { background:var(--ok-soft); color:var(--ok) }
  .sub { color:var(--muted); margin:0 0 20px }
  .rows { list-style:none; margin:0; padding:0 }
  .rows li { display:flex; justify-content:space-between; gap:16px; padding:9px 0; border-bottom:1px solid var(--line) }
  .rows li:last-child { border-bottom:0 }
  .rows span { color:var(--muted); font-variant-numeric:tabular-nums }
  .chips { display:flex; flex-wrap:wrap; gap:6px }
  .chips span { padding:2px 10px; border:1px solid var(--line); border-radius:999px; font-size:14px }
  .empty { color:var(--muted); margin:0 }
  footer { margin-top:28px; padding-top:16px; border-top:1px solid var(--line); color:var(--muted); font-size:13px }
'@

# Odliczanie na żywo. Pozostały czas podaje serwer (data-ms), więc zegar przeglądarki nie musi się zgadzać.
$CountdownJs = @'
(function () {
  var el = document.getElementById('left');
  if (!el) return;
  var end = Date.now() + Number(el.getAttribute('data-ms'));
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function fmt(s) {
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60), x = s % 60;
    if (d) return d + ' d ' + pad(h) + ':' + pad(m) + ':' + pad(x);
    if (h) return h + ':' + pad(m) + ':' + pad(x);
    return pad(m) + ':' + pad(x);
  }
  var timer = setInterval(tick, 1000);
  function tick() {
    var s = Math.max(0, Math.ceil((end - Date.now()) / 1000));
    el.textContent = fmt(s);
    if (s > 0) return;
    clearInterval(timer);
    if (el.getAttribute('data-done') === 'reload') {
      setTimeout(function () { location.reload(); }, 3000);
    } else {
      document.body.classList.add('done');
      var h = document.getElementById('head');
      if (h) h.textContent = 'Blokada się skończyła';
      document.title = 'Blokada się skończyła – FocusBlocker';
    }
  }
  tick();
})();
'@

function Format-Timer([TimeSpan]$Left) {
    $s = [int64][math]::Max(0, [math]::Ceiling($Left.TotalSeconds))
    $d = [int64][math]::Floor($s / 86400); $h = [int64][math]::Floor(($s % 86400) / 3600)
    $m = [int64][math]::Floor(($s % 3600) / 60); $x = $s % 60
    if ($d -gt 0) { return '{0} d {1:00}:{2:00}:{3:00}' -f $d, $h, $m, $x }
    if ($h -gt 0) { return '{0}:{1:00}:{2:00}' -f $h, $m, $x }
    return '{0:00}:{1:00}' -f $m, $x
}

function Get-CountdownHtml([string]$Label, [datetime]$Until, [string]$OnDone) {
    $left = $Until - (Get-FBNow)
    $ms = [int64][math]::Max(0, $left.TotalMilliseconds)
    return @"
  <div class="countdown">
    <div class="label">$Label</div>
    <div class="timer" id="left" data-ms="$ms" data-done="$OnDone">$(Format-Timer $left)</div>
    <div class="until">do <b>$(Format-FBWhen $Until)</b></div>
  </div>
"@
}

function Get-PageHtml([string]$Title, [string]$Body, [string]$BodyClass) {
    return @"
<!doctype html>
<html lang="pl"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$Title – FocusBlocker</title>
<link rel="icon" href="$Favicon">
<style>
$PageCss
</style></head>
<body class="$BodyClass"><main>
  <div class="brand">$Logo FocusBlocker</div>
$Body
  <footer>Zmiany: menu FocusBlocker w menu Start.</footer>
</main>
<script>
$CountdownJs
</script>
</body></html>
"@
}

function Get-BlockedPage([string]$Site) {
    $st = Get-FBStatus
    $now = Get-FBNow
    $day = $now.ToString('yyyy-MM-dd')
    if ($st.Active) {
        if (-not $attempts.ContainsKey($day)) { $attempts.Clear(); $attempts[$day] = 0 }
        $attempts[$day]++
    }
    $count = if ($attempts.ContainsKey($day)) { $attempts[$day] } else { 0 }

    $site = if ($Site) { ConvertTo-HtmlText $Site } else { 'Ta strona' }
    $msg  = ConvertTo-HtmlText $st.Message
    # Przycisk powrotu tylko dla poprawnej nazwy domeny (trafia do atrybutu href)
    $domain = if ($Site) { $Site.ToLowerInvariant() } else { '' }
    $goBack = if ($domain -match '^[a-z0-9-]+(\.[a-z0-9-]+)+$') { "<a class=""btn"" href=""https://$domain/"">Przejdź do $domain</a>" } else { '' }
    $ended = "  <div class=""ended""><p>Możesz już wrócić na tę stronę. Jeśli jeszcze się nie wczytuje, odczekaj minutę.</p>$goBack</div>"

    if ($st.Active) {
        $head = 'Zablokowane'
        $tries = switch ($count) {
            1       { 'To Twoja pierwsza próba dzisiaj.' }
            { $_ -ge 2 -and $_ -le 4 } { "To już $count. próba dzisiaj." }
            default { "To już $count. próba dzisiaj. Może czas na przerwę od ekranu?" }
        }
        $body = @"
  <h1 id="head">$head</h1>
  <p class="site">$site</p>
  <p class="msg">$msg</p>
$(Get-CountdownHtml 'Do końca blokady zostało' $st.Until 'show')
  <p class="tries">$tries</p>
$ended
"@
        return Get-PageHtml $head $body ''
    }

    $head = 'Blokada się skończyła'
    $body = @"
  <h1 id="head">$head</h1>
  <p class="site">$site</p>
$ended
"@
    return Get-PageHtml $head $body 'done'
}

function Get-IndexPage {
    $st = Get-FBStatus
    if ($st.Active) {
        $top = @"
  <span class="pill on">Blokada aktywna</span>
  <h1>Skup się – strony są zablokowane</h1>
  <p class="sub">Powód: $(ConvertTo-HtmlText $st.Reason)</p>
$(Get-CountdownHtml 'Do końca blokady zostało' $st.Until 'reload')
"@
    } elseif ($st.NextStart) {
        $top = @"
  <span class="pill off">Brak blokady</span>
  <h1>Wszystkie strony są dostępne</h1>
$(Get-CountdownHtml 'Następna blokada za' $st.NextStart 'reload')
"@
    } else {
        $top = @"
  <span class="pill off">Brak blokady</span>
  <h1>Wszystkie strony są dostępne</h1>
  <p class="sub">Harmonogram jest pusty – blokadę włączysz z menu FocusBlocker.</p>
"@
    }

    $sched = @($st.Config.Schedule | ForEach-Object {
        "    <li>$(ConvertTo-HtmlText (Format-FBDays $_.Days)) <span>$(ConvertTo-HtmlText $_.From)–$(ConvertTo-HtmlText $_.To)</span></li>"
    })
    $schedHtml = if ($sched.Count) { "  <ul class=""rows"">`r`n" + ($sched -join "`r`n") + "`r`n  </ul>" } else { '  <p class="empty">Brak przedziałów.</p>' }

    $list = @(Get-FBListEntries)
    $listHtml = if ($list.Count) {
        '  <div class="chips">' + (($list | ForEach-Object { '<span>' + (ConvertTo-HtmlText $_) + '</span>' }) -join '') + '</div>'
    } else { '  <p class="empty">Lista jest pusta.</p>' }

    $body = @"
$top
  <h2>Harmonogram</h2>
$schedHtml
  <h2>Zablokowane strony ($($list.Count))</h2>
$listHtml
"@
    return Get-PageHtml 'Stan blokady' $body ''
}

# ------------------------------------------------------------------ pętla serwera

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$FB_Port/")
$listener.Start()
Write-FBLog "Serwer strony blokady uruchomiony na porcie $FB_Port"

$pending = $null
$lastSync = [datetime]::MinValue
try {
    while ($listener.IsListening) {
        if ((Get-Date) - $lastSync -ge [TimeSpan]::FromSeconds(30)) {
            try { [void](Invoke-FBAuto) } catch { Write-FBLog "Błąd synchronizacji: $($_.Exception.Message)" }
            $lastSync = Get-Date
        }
        if (-not $pending) { $pending = $listener.BeginGetContext($null, $null) }
        if (-not $pending.AsyncWaitHandle.WaitOne(5000)) { continue }
        $ctx = $listener.EndGetContext($pending)
        $pending = $null
        try {
            $path = $ctx.Request.Url.AbsolutePath.TrimEnd('/')
            switch ($path) {
                '/status'  { Send-Response $ctx 200 'application/json' (Get-StatusJson) }
                '/blocked' { Send-Response $ctx 200 'text/html' (Get-BlockedPage $ctx.Request.QueryString['site']) }
                ''         { Send-Response $ctx 200 'text/html' (Get-IndexPage) }
                default    { Send-Response $ctx 404 'text/plain' 'Not found' }
            }
        } catch {
            Write-FBLog "Błąd serwera: $($_.Exception.Message)"
            try { Send-Response $ctx 500 'text/plain' 'Error' } catch { }
        } finally {
            try { $ctx.Response.Close() } catch { }
        }
    }
} finally {
    $listener.Close()
}
