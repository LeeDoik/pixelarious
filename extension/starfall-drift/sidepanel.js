// 사이드 패널 셸: 라이브 사이트의 게임을 iframe으로 띄우고, 오프라인이면 안내 화면을 보여준다.
// cross-origin iframe은 로드 실패를 신뢰성 있게 알 수 없으므로 navigator.onLine만 본다.

const GAME_URL = 'https://www.pixelarious.online/games/starfall-drift/index.html'
const SITE_URL = 'https://www.pixelarious.online/'

const frame = document.getElementById('game')
const offline = document.getElementById('offline')
const retry = document.getElementById('retry')

/** chrome.i18n으로 정적 문구를 현지화. 확장 CSP상 인라인 스크립트를 못 쓰므로 여기서 처리. */
function localize() {
  const t = (key) => chrome.i18n.getMessage(key)
  const set = (id, key, prop = 'textContent') => {
    const el = document.getElementById(id)
    const msg = t(key)
    if (el && msg) el[prop] = msg
  }
  set('offline-title', 'offlineTitle')
  set('offline-body', 'offlineBody')
  set('retry', 'retry')
  set('site-link', 'siteLink')
  const title = t('gameFrameTitle')
  if (title) frame.title = title
  const link = document.getElementById('site-link')
  if (link) link.href = SITE_URL
}

/** 게임 프레임을 (재)로드. 캐시 무시가 아니라 단순 src 재설정 — 게임 자체가 최신본을 받아온다. */
function loadGame() {
  frame.src = GAME_URL
}

function render() {
  const online = navigator.onLine
  offline.hidden = online
  frame.hidden = !online
  if (online && !frame.src) loadGame()
}

retry.addEventListener('click', () => {
  if (navigator.onLine) loadGame()
  render()
})

window.addEventListener('online', render)
window.addEventListener('offline', render)

localize()
render()
