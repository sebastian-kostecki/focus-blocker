// FocusBlocker - rozszerzenie dla Chrome i Edge.
// Pyta lokalny serwer FocusBlockera o stan blokady i przekierowuje
// zablokowane strony na stronę z komunikatem. Samą blokadę robi plik hosts -
// rozszerzenie odpowiada tylko za ładny komunikat zamiast błędu połączenia.

const SERVER = 'http://127.0.0.1:47615';
const CACHE_MS = 20000;

let cache = { at: 0, data: null };
const recent = new Map(); // tabId -> czas ostatniego przekierowania

async function getStatus(force) {
  if (!force && Date.now() - cache.at < CACHE_MS) return cache.data;
  try {
    const res = await fetch(SERVER + '/status', { cache: 'no-store' });
    cache = { at: Date.now(), data: res.ok ? await res.json() : null };
  } catch (e) {
    cache = { at: Date.now(), data: null }; // serwer nie działa - nic nie robimy
  }
  return cache.data;
}

function isBlockedHost(host, domains) {
  host = host.toLowerCase().replace(/\.$/, '');
  return domains.some((d) => host === d || host.endsWith('.' + d));
}

async function check(tabId, url, force) {
  if (tabId < 0) return;
  let u;
  try { u = new URL(url); } catch (e) { return; }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') return;
  if (u.hostname === '127.0.0.1' || u.hostname === 'localhost') return;

  const s = await getStatus(force);
  if (!s || !s.active || !Array.isArray(s.domains)) return;
  if (!isBlockedHost(u.hostname, s.domains)) return;

  const last = recent.get(tabId) || 0;
  if (Date.now() - last < 3000) return; // nie przekierowuj dwa razy tej samej karty
  recent.set(tabId, Date.now());

  chrome.tabs.update(tabId, {
    url: SERVER + '/blocked?site=' + encodeURIComponent(u.hostname),
  });
}

// Nowa nawigacja na zablokowaną stronę
chrome.webNavigation.onBeforeNavigate.addListener((d) => {
  if (d.frameId === 0) check(d.tabId, d.url, false);
});

// Strona się nie wczytała (plik hosts zadziałał) - sprawdź na świeżo
chrome.webNavigation.onErrorOccurred.addListener((d) => {
  if (d.frameId === 0) check(d.tabId, d.url, true);
});

// Co minutę: gdy blokada właśnie się zaczęła, zamień też już otwarte karty
async function sweepTabs() {
  const s = await getStatus(true);
  if (!s || !s.active) return;
  const tabs = await chrome.tabs.query({});
  for (const t of tabs) {
    if (t.id !== undefined && t.url) check(t.id, t.url, false);
  }
}

chrome.alarms.onAlarm.addListener((a) => {
  if (a.name === 'sweep') sweepTabs();
});

function setup() {
  chrome.alarms.create('sweep', { periodInMinutes: 1 });
  sweepTabs();
}
chrome.runtime.onInstalled.addListener(setup);
chrome.runtime.onStartup.addListener(setup);

chrome.tabs.onRemoved.addListener((tabId) => recent.delete(tabId));
