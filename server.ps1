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

function ConvertTo-Html([string]$Text) { return [System.Net.WebUtility]::HtmlEncode($Text) }

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

function Get-BlockedPage([string]$Site) {
    $st = Get-FBStatus
    $now = Get-FBNow
    $day = $now.ToString('yyyy-MM-dd')
    if ($st.Active) {
        if (-not $attempts.ContainsKey($day)) { $attempts.Clear(); $attempts[$day] = 0 }
        $attempts[$day]++
    }
    $count = if ($attempts.ContainsKey($day)) { $attempts[$day] } else { 0 }

    $site = if ($Site) { ConvertTo-Html $Site } else { 'Ta strona' }
    $msg  = ConvertTo-Html $st.Message
    if ($st.Active) {
        $head = 'Zablokowane'
        $info = 'Blokada potrwa do <b>{0}</b> – zostało {1}.' -f (Format-FBWhen $st.Until), (Format-FBDuration ($st.Until - $now))
        $tries = switch ($count) {
            1       { 'To Twoja pierwsza próba dzisiaj.' }
            { $_ -ge 2 -and $_ -le 4 } { "To już $count. próba dzisiaj." }
            default { "To już $count. próba dzisiaj. Może czas na przerwę od ekranu?" }
        }
    } else {
        $head = 'Blokada się skończyła'
        $info = 'Możesz już wejść na tę stronę – odśwież kartę.'
        $tries = ''
    }

    return @"
<!doctype html>
<html lang="pl"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$head – FocusBlocker</title>
<style>
  :root { --bg:#f6f5f2; --card:#fff; --text:#1d1d1f; --muted:#6b6b70; --accent:#c2410c; --line:#e7e5e0; }
  @media (prefers-color-scheme: dark) {
    :root { --bg:#141416; --card:#1d1d20; --text:#ececee; --muted:#9a9aa2; --accent:#fb923c; --line:#2c2c31; }
  }
  * { box-sizing:border-box }
  body { margin:0; min-height:100vh; display:grid; place-items:center; padding:24px 16px;
         background:var(--bg); color:var(--text); font:16px/1.55 "Segoe UI",system-ui,sans-serif; }
  main { width:100%; max-width:560px; background:var(--card); border:1px solid var(--line);
         border-radius:16px; padding:40px 36px; }
  .tag { display:inline-block; font-size:13px; letter-spacing:.06em; text-transform:uppercase;
         color:var(--accent); font-weight:600; margin-bottom:14px }
  h1 { font-size:28px; line-height:1.25; margin:0 0 6px; font-weight:650 }
  .site { color:var(--muted); margin:0 0 26px; word-break:break-all }
  .msg { font-size:20px; line-height:1.5; margin:0 0 26px; padding-left:16px; border-left:3px solid var(--accent) }
  .info { margin:0 0 6px }
  .tries { margin:0; color:var(--muted); font-size:14px }
  footer { margin-top:28px; padding-top:16px; border-top:1px solid var(--line); color:var(--muted); font-size:13px }
</style></head>
<body><main>
  <div class="tag">FocusBlocker</div>
  <h1>$head</h1>
  <p class="site">$site</p>
  <p class="msg">$msg</p>
  <p class="info">$info</p>
  <p class="tries">$tries</p>
  <footer>Zmiany: menu FocusBlocker w menu Start.</footer>
</main></body></html>
"@
}

function Get-IndexPage {
    $st = Get-FBStatus
    $state = if ($st.Active) { "Blokada aktywna do $(Format-FBWhen $st.Until) ($(ConvertTo-Html $st.Reason))" } else { 'Brak blokady' }
    return "<!doctype html><meta charset=utf-8><title>FocusBlocker</title><body style=""font:16px system-ui;padding:24px""><h1>FocusBlocker</h1><p>$state</p><p>Domen na liście: $(@($st.Domains).Count)</p>"
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
