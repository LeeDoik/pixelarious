# NEO_KIDO

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

## 배너 내용 편집기

```bash
npm run dev   # http://localhost:3000/editor
```

제목·부제·설명·태그·커버를 고치고 저장하면 `content/games`의 JSON 파일에 바로 기록된다.
오른쪽에는 실제 배너 컴포넌트가 그대로 프리뷰로 뜬다.

설명(description)에서 **엔터로 줄을 나누면 배너에도 그대로 나온다** (빈 줄 = 문단 구분).
`.desc`가 `white-space: pre-wrap`이라 개행이 보존된다.

편집기와 저장 API(`/api/editor`)는 **개발 서버에서만** 열린다. 배포된 사이트에서는 둘 다 404다.
저장한 뒤에는 커밋하고 푸시해야 사이트에 반영된다.

## 테마

NIGHT(PICO-8 계열) / DMG(게임보이 4색) — 우상단 PALETTE SWAP.
선택은 localStorage(`palette`)에 저장된다. 새 UI는 두 팔레트 모두에서 확인할 것.
