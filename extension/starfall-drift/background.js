// 툴바 아이콘 클릭 = 사이드 패널 열기. 이 확장의 유일한 백그라운드 동작.
chrome.sidePanel
  .setPanelBehavior({ openPanelOnActionClick: true })
  .catch((err) => console.error('[starfall-drift] setPanelBehavior', err))
