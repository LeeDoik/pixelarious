# PIXELARIOUS

1인 개발자 LeeDoik의 게임을 브라우저에서 바로 플레이하는 픽셀 아케이드.

- 디자인 스펙: `docs/superpowers/specs/2026-08-13-neo-kido-design.md`
- 시각 기준 목업: `docs/superpowers/specs/2026-08-13-neo-kido-mockup.html`

## 개발

```bash
npm install
npm run dev    # http://localhost:3000
npm test       # vitest
npm run build  # 프로덕션 빌드
```

## 게임 추가하는 법 (게임 = 데이터 레코드)

1. 게임 웹 빌드를 `public/games/<slug>/`에 넣는다 (`index.html` 필수).
   - Godot 4.3+: 웹 익스포트 시 **Thread Support 비활성화** (특수 헤더 불필요)
2. `content/games/<순번>-<slug>.json` 레코드를 만든다:

```json
{
  "slug": "my-game",
  "order": 40,
  "title": "MY GAME",
  "subtitle": "한글 부제 (선택)",
  "description": "한국어 설명.",
  "tags": ["GODOT 4", "2D", "WEB"],
  "coverScene": "starfall",
  "playPath": "/games/my-game/index.html"
}
```

3. `npm test` — 레지스트리가 슬러그 중복·파일 존재를 검증한다.
4. `src/lib/games.test.ts`의 playable 목록 테스트에 슬러그를 추가한다.
5. 커밋하고 푸시하면 Vercel이 자동 배포한다.

`coverScene`은 `starfall | cave | pong | system` 중 하나 (절차적 커버).
이미지 커버는 Phase 1.5에서 추가 예정.

## 사이트 편집기

```bash
npm run dev   # http://localhost:3000/editor
```

위쪽 탭에서 편집 대상을 고른다.

- **게임 카트리지** — 제목·부제·설명·태그·커버 → `content/games/*.json`
- **PLAYER 1** — 소개글·링크 버튼·배지 → `content/profile.json`

오른쪽에는 실제 컴포넌트가 그대로 프리뷰로 뜬다.

설명과 소개글에서 **엔터로 줄을 나누면 화면에도 그대로 나온다** (빈 줄 = 문단 구분).
`.desc`와 `.about p`가 `white-space: pre-wrap`이라 개행이 보존된다.

링크는 이름과 주소를 **둘 다** 채운 것만 저장되고 화면에 나온다 (죽은 링크 금지 — 스펙 §4.3).
링크를 모두 지우면 버튼 줄이 통째로 숨겨진다.

편집기와 저장 API(`/api/editor`)는 **개발 서버에서만** 열린다. 배포된 사이트에서는 둘 다 404다.
저장한 뒤에는 커밋하고 푸시해야 사이트에 반영된다.

## 브랜드 자산 (SNS)

```bash
npm run dev   # http://localhost:3000/brand
```

프로필·파비콘·유튜브 배너·쇼츠 카드·포스트 템플릿 4종을 실제 크기로 렌더하고
"PNG 내보내기"로 받는다. 디자인 툴을 쓰지 않는 이유는 팔레트와 폰트를 사이트와
공유해서 색이 어긋나지 않게 하기 위해서다.

- 스펙: `docs/superpowers/specs/2026-08-16-pixelarious-brand-design.md`
- 렌더링 로직: `src/lib/brand.ts` (DOM 비의존 — 전부 단위 테스트됨)
- **내보낸 PNG는 저장소에 커밋하지 않는다.** 필요할 때 다시 렌더한다

`/brand`는 `/editor`와 같이 **개발 서버에서만** 열린다. 배포된 사이트에서는 404다.

포스트 템플릿은 용도로 나눠 쓴다 — 출시는 B(카트리지), 게임 화면은 A(풀블리드),
개발일지는 C(터미널 로그), 의견 수집은 D(질문 카드).
이미지 안에는 제목·라벨·질문만 넣는다. 캡션은 인스타·스레드에서 이미지 바깥에 붙는다.

## 테마

NIGHT(PICO-8 계열) / DMG(게임보이 4색) — 우상단 PALETTE SWAP.
선택은 localStorage(`palette`)에 저장된다. 새 UI는 두 팔레트 모두에서 확인할 것.
