# 크롬 웹 스토어 리스팅 문구

대시보드에 그대로 붙여 넣는 원문. 언어별 리스팅을 둘 다 등록한다(영어 = 기본).

---

## English (default)

**Name** (45자 이하)

```
STARFALL DRIFT
```

**Short description** (132자 이하)

```
Play STARFALL DRIFT, a one-button pixel arcade game, in your Chrome side panel.
```

**Detailed description**

```
STARFALL DRIFT is a one-button pixel arcade game that lives in your Chrome side panel.

Your ship orbits a dying star. Tap — that is the whole control scheme — to release and
drift to the next one. Miss, and the void takes you. Chain clean transfers to stack
combos and push your run further out.

WHY THE SIDE PANEL
The game is a tall, narrow, single-tap arcade cartridge, so it fits the side panel
exactly. Keep it open beside your work and take a run whenever you need thirty seconds
away from the tab you were staring at. Closing the panel does not close your tabs.

WHAT YOU GET
- One-button controls: tap or click, nothing else to learn
- Fast runs — a game lasts under a minute
- Combo scoring that rewards tight, late releases
- Your best score is remembered locally by your browser
- Pixel art and a chiptune soundtrack made for the cartridge

PRIVACY
This extension collects nothing. It requests a single permission, "sidePanel", so it
can open the panel. It has no host permissions and no content scripts, which means it
cannot read or change the pages you browse. Your score stays in your browser.

The extension loads the game from pixelarious.online, so an internet connection is
required. Made by PIXELARIOUS — more cartridges at https://www.pixelarious.online/
```

**Category**: Games
**Language**: English

**Single purpose** (심사용 단일 목적 서술)

```
The single purpose of this extension is to let the user play the game STARFALL DRIFT
in the Chrome side panel. It opens one page — the game — and does nothing else.
```

**Permission justification — `sidePanel`**

```
The extension's entire function is to render the game inside Chrome's side panel, which
requires the sidePanel permission. No other permission is requested.
```

**Remote code**: 확장 패키지에는 원격 스크립트가 없고 게임은 원격 iframe(자체 출처에서
실행)으로만 뜬다 — 크롬 문서상 원격 iframe은 원격 코드의 허용 대안으로 분류되지만,
패널 내용 자체가 원격에서 온다는 점을 숨기지 않는 편이 심사에서 안전하다.
**"Yes, I am using remote code"** 를 고르고 아래 설명을 붙인다.

```
The side panel embeds https://www.pixelarious.online/games/starfall-drift/index.html in
an iframe. That page is the game itself, published by the same developer as this
extension. Nothing is injected into other sites, and the extension bundles no
downloaded scripts of its own.
```

**Data usage**: 모든 항목 체크 해제(수집 없음) + 세 개 선언 모두 체크
(제3자 판매 안 함 / 목적 외 사용 안 함 / 신용도 평가 등에 사용 안 함).

**Privacy policy URL**

```
https://www.pixelarious.online/extension/privacy.html
```

---

## 한국어

**이름**

```
STARFALL DRIFT
```

**요약**

```
원 버튼 픽셀 아케이드 게임 STARFALL DRIFT를 크롬 사이드 패널에서 플레이하세요.
```

**상세 설명**

```
STARFALL DRIFT는 크롬 사이드 패널에서 돌아가는 원 버튼 픽셀 아케이드 게임입니다.

당신의 배는 꺼져가는 별의 궤도를 돕니다. 조작은 탭 하나뿐 — 손을 놓아 다음 별로
날아가세요. 놓치면 그대로 우주에 삼켜집니다. 궤도를 깔끔하게 갈아탈수록 콤보가 쌓이고,
기록은 더 멀리 나아갑니다.

왜 사이드 패널인가
세로로 길고 탭 하나로 조작하는 게임이라 사이드 패널 비율에 정확히 맞습니다. 작업창
옆에 열어두고 30초가 필요할 때마다 한 판 하세요. 패널을 닫아도 보던 탭은 그대로입니다.

특징
- 원 버튼: 탭 또는 클릭, 배울 것이 없습니다
- 한 판 1분 이내의 짧은 호흡
- 늦게 놓을수록 크게 붙는 콤보 점수
- 최고 점수는 브라우저에 로컬로 저장됩니다
- 이 카트리지를 위해 만든 픽셀 아트와 칩튠 사운드

개인정보
이 확장은 어떤 데이터도 수집하지 않습니다. 요청하는 권한은 패널을 여는 "sidePanel"
하나뿐이며, 호스트 권한과 콘텐츠 스크립트가 없어 사용자가 보는 웹페이지를 읽거나
바꿀 수 없습니다. 점수는 브라우저 안에만 남습니다.

게임은 pixelarious.online에서 불러오므로 인터넷 연결이 필요합니다.
만든 곳: PIXELARIOUS — 다른 카트리지는 https://www.pixelarious.online/
```

---

## 이미지 자산

| 항목 | 규격 | 파일 |
| --- | --- | --- |
| 스토어 아이콘 | 128×128 | `../starfall-drift/icons/icon128.png` |
| 스크린샷 ×3 | 1280×800 | `screenshot-1..3-1280x800.png` (실제 캡처 필요, `captures/README.md` 참고) |
| 소형 프로모 타일 | 440×280 | `promo-440x280.png` |

마키 프로모 타일(1400×560)은 선택 사항이라 만들지 않았다. 추후 필요하면
`scripts/gen_store_assets.py`에 같은 방식으로 추가한다.
