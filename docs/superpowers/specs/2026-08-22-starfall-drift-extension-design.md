# STARFALL DRIFT 크롬 사이드 패널 확장 — 설계

2026-08-22. 크롬 웹 스토어 공개 배포용.

## 목적

STARFALL DRIFT를 크롬 사이드 패널에서 플레이할 수 있는 확장 프로그램을 만들어
누구나 웹 스토어에서 검색·설치할 수 있게 한다. 게임은 세로 270×480·탭 단일 조작이라
사이드바 폼팩터에 정확히 맞는다.

## 결정 사항

- **범위**: STARFALL DRIFT 단독 확장. 아케이드(게임 선택기)형은 채택하지 않음 —
  LAST LOGIN은 가로형 데스크톱 시뮬레이션이라 사이드바에서 플레이 불가.
- **로딩 방식**: 라이브 사이트 iframe. 확장은 `https://www.pixelarious.online/games/starfall-drift/index.html`을
  띄우는 껍데기만 담는다. 게임 업데이트는 사이트 배포만으로 확장에 즉시 반영되고
  스토어 재심사가 필요 없다. (사이트는 `X-Frame-Options`/`frame-ancestors`를 보내지
  않음을 2026-08-22 실측 확인 — 이 전제가 깨지면 확장이 통째로 죽으므로, 사이트에
  프레임 차단 헤더를 추가하지 않는다는 제약이 생긴다. next.config.ts에 주석으로 남길 것.)
- **오프라인 번들(B안)은 하지 않음**: 42MB wasm 동봉 + CSP 셸 수정 + 게임 수정마다
  재심사라는 비용 대비, 오프라인 플레이 수요가 검증되지 않았다.

## 구성 요소

저장소에 `extension/starfall-drift/` 디렉터리 신설. 사이트 빌드(Next.js)와 완전히 분리되어
있고 npm 의존성이 없다 — 순수 정적 파일.

```
extension/starfall-drift/
├── manifest.json        MV3. permissions: ["sidePanel"]뿐. minimum_chrome_version "114"
├── background.js        서비스 워커 한 줄대: setPanelBehavior({openPanelOnActionClick: true})
├── sidepanel.html       패널 UI (아래 UX 절)
├── sidepanel.css        패널 스타일 (픽셀 톤, 게임과 같은 배경색 #1A1423 계열)
├── sidepanel.js         온라인 감지·재시도 (인라인 스크립트는 확장 CSP상 금지라 외부 파일)
├── _locales/
│   ├── en/messages.json 이름·설명 (default_locale)
│   └── ko/messages.json
└── icons/
    ├── icon16.png  icon32.png  icon48.png  icon128.png
```

### manifest.json 골자

```json
{
  "manifest_version": 3,
  "name": "__MSG_extName__",
  "description": "__MSG_extDesc__",
  "default_locale": "en",
  "version": "1.0.0",
  "minimum_chrome_version": "114",
  "permissions": ["sidePanel"],
  "side_panel": { "default_path": "sidepanel.html" },
  "action": { "default_title": "__MSG_extName__" },
  "background": { "service_worker": "background.js" },
  "icons": { "16": "...", "32": "...", "48": "...", "128": "..." }
}
```

호스트 권한·콘텐츠 스크립트·storage 없음. 심사 마찰 최소화가 목적.

## 사이드 패널 UX

- 패널 전체를 iframe이 채운다 (`width/height 100%`, border 없음). 게임 캔버스가
  adaptive라 좁고 긴 패널에 자연히 맞는다.
- **하단 바 한 줄**(높이 ~24px): "PIXELARIOUS ↗" 텍스트 링크 — `target="_blank"`로
  사이트 홈 이동. 확장→사이트 유입 통로이자 브랜드 표기.
- **오프라인 폴백**: `navigator.onLine`이 false거나 `offline` 이벤트 수신 시 iframe을
  숨기고 안내 화면(픽셀 톤 문구 + RETRY 버튼)을 보여준다. RETRY는 iframe `src` 재설정.
  cross-origin iframe은 로드 실패를 신뢰성 있게 알 수 없으므로 이 이상의 감지는
  과설계로 보고 하지 않는다.
- 그 외 UI 없음. 일시정지·음소거·점수는 전부 게임 자체 기능.

## 아이콘·스토어 리스팅 자산

- 확장 아이콘 4종: 게임의 별/플레이어 스프라이트(`games-src/starfall-drift/assets/img/`)
  기반으로 생성. 기존 `scripts/gen_icons.py` 패턴을 따라 `scripts/gen_extension_icons.py`
  추가 (Pillow, 니어리스트 확대로 픽셀 유지).
- 스토어 스크린샷 1280×800 3장: 실제 게임플레이 캡처(타이틀 / 콤보 플레이 / 게임오버)를
  사이드 패널 목업 프레임에 합성. 스크립트로 생성해 `extension/store-assets/`에 보관
  (zip에는 미포함 — 스토어 대시보드 업로드용).
- 소형 프로모 타일 440×280 1장.
- 리스팅 문구(한/영)는 `extension/store-assets/listing.md`에 정리: 이름 "STARFALL DRIFT",
  요약, 상세 설명, 단일 목적(single purpose) 설명, 데이터 수집 없음 선언 문구.

## 개인정보 처리방침

`public/extension/privacy.html` 정적 페이지 추가 (한/영 병기, "이 확장은 어떤 데이터도
수집·저장·전송하지 않는다" 명시). 배포되면
`https://www.pixelarious.online/extension/privacy.html`을 스토어 리스팅의 개인정보
처리방침 URL로 사용.

## 검증

- `manifest.json` JSON 유효성 + 필수 키 존재를 확인하는 vitest 테스트 1건
  (`src/lib/` 테스트들과 같은 러너에 편승, `extension/` 파일을 읽어 검증).
- 수동 검증: `chrome://extensions` → 개발자 모드 → "압축해제된 확장 프로그램 로드"로
  `extension/starfall-drift/` 로드 → 툴바 아이콘 클릭 → 사이드 패널에서 게임 부팅·플레이 확인.
  오프라인 폴백은 DevTools Network offline으로 확인.
- zip 패키징: `scripts/pack_extension.py` — `extension/starfall-drift/` →
  `extension/dist/starfall-drift-v<version>.zip` (버전은 manifest에서 읽음). dist는 gitignore.

## 배포 절차 (역할 분담)

**Claude가 준비**: 위 전부 — 확장 파일, 아이콘, 스크린샷, 리스팅 문구, 개인정보 페이지,
zip, 제출 단계별 안내서(`extension/store-assets/SUBMIT.md`).

**사용자가 직접**: Chrome 웹 스토어 개발자 등록(구글 계정, 1회 US$5) →
대시보드에서 zip 업로드 → 리스팅 문구/이미지 붙여넣기 → 개인정보 탭 작성
("데이터 수집 안 함" 체크) → 심사 제출. 통상 수일 내 게시.

## 성공 기준

- 웹 스토어 검색으로 설치한 확장에서: 아이콘 클릭 → 사이드 패널 → 게임 플레이 가능,
  점수 저장(IndexedDB) 유지, 콘솔 에러 없음.
- 이후 게임 재배포 시 확장 재제출 없이 자동 반영.

## 하지 않는 것

- 게임 선택기 / 다른 게임 노출 (수요 확인 후 별도 프로젝트)
- 오프라인 번들, 자체 점수 동기화, 분석/텔레메트리, options 페이지
