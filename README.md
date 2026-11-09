# PIXELARIOUS

직접 만든 게임과 소프트웨어를 한 자리씩 둘러보고 체험하는 네온 오락실.

| | |
|---|---|
| ▶ **사이트** | **https://www.pixelarious.online** |
| 👤 **개발** | 이도익 1인 — 기획 · 개발 · 배포 · 운영 |
| 🛠 **스택** | Next.js 15 · React 19 · Three.js · TypeScript · Vitest · Vercel / 게임: Godot 4 (웹 익스포트) |

---

## 수록 게임

| 게임 | 장르 | 한 줄 소개 |
|---|---|---|
| **STARFALL DRIFT** | 원버튼 아케이드 | 탭 한 번으로 궤도를 바꿔, 별이 부서지기 전에 다음 별로 건너간다 |
| **IT SLEEPS BELOW** | 로그라이크 채굴 | 곡괭이 하나로 내려갈수록 어두워지는 갱도를 판다 |
| **LAST LOGIN** | 미스터리 어드벤처 | 2003년 겨울 주워 온 컴퓨터에서 3개월 전에 멈춘 한 사람의 삶을 따라간다 |
| **PIXEL PONG.EXE** | 아케이드 (1-day jam) | 공이 벽에 닿을 때마다 규칙이 하나씩 바뀌는 퐁 |

STARFALL DRIFT는 크롬 사이드 패널에서 띄우는 확장으로도 만들었습니다 (`extension/`, 권한 `sidePanel` 하나).

---

## 설계

### 히어로에서 네온 오락실로

기존 로고 타이핑 연출을 네온 입구로 살리고, 전시실·제작자 데스크·푸터·게임 실행 화면까지
같은 조명, 버튼, 테두리, 여백 규칙으로 연결했습니다. 상단 안내판에서 입구·작품·제작자로
바로 이동하며, 현재 보고 있는 공간이 표시됩니다. 공통 스타일은 `src/app/arcade.css`에 있습니다.

Three.js 게임기 영역을 위·아래 또는 좌·우로
드래그하면 한 자리씩 이동합니다. 휠·트랙패드는 관성 스크롤까지 한 번의 입력으로 처리하고,
방향키와 이전·다음 버튼도 지원합니다. 첫 자리에서는 입구로, 마지막 자리에서는 PLAYER 1으로 이어집니다.

3D 장면은 오락실이 화면에 들어올 때 불러오고, 이동이나 화면 변경이 있을 때만 그립니다.
WebGL을 사용할 수 없어도 2D 게임기와 작품 링크는 작동합니다. 모션 줄이기 설정과 NIGHT/DMG 팔레트를 따릅니다.
높이가 짧은 화면에서는 페이지 스크롤을 유지하고 드래그·버튼으로 작품을 고릅니다.

공개 게임은 기존 레지스트리에서 읽으며 `hidden`인 게임은 전시하지 않습니다.
게임 외 작품은 `content/software.json`에 추가합니다. `slug`, `title`, `description`, `tags`,
`coverScene`, HTTPS `href`가 필수이고 `category`, `subtitle`, `coverImage`는 선택입니다.
현재 크롬 사이드 패널 확장은 저장소의 설치 안내로 연결됩니다. 편집기는 기존 게임·프로필 편집을 유지합니다.

### 게임 하나 = JSON 레코드 하나

게임을 추가할 때 코드를 고치지 않습니다. `public/games/<slug>/`에 웹 빌드를 넣고
`content/games/*.json` 레코드를 하나 추가하면 오락실 게임기와 플레이 화면(`/play/[slug]`)이 만들어집니다.
레지스트리 테스트가 slug 중복과 빌드 파일 존재를 검사합니다.

```json
{
  "slug": "starfall-drift",
  "order": 10,
  "title": "STARFALL DRIFT",
  "description": "탭 한 번으로 궤도를 변경하세요. …",
  "tags": ["GODOT 4", "2D", "ARCADE"],
  "coverScene": "starfall",
  "playPath": "/games/starfall-drift/index.html"
}
```

### 편집기와 배포 버튼 — 개발 서버에서만

문구 하나를 고칠 때마다 터미널을 열지 않도록, 사이트 안에 편집기(`/editor`)와 배포 버튼을 두었습니다.
공개 사이트를 바꾸는 기능이라 경계를 좁게 잡았습니다.

- **개발 서버 전용.** `/editor` · `/api/editor` · `/api/deploy`는 `NODE_ENV=development`에서만 열립니다. 배포된 사이트에서는 404입니다.
- **바꿀 수 있는 필드를 제한.** 라우팅을 결정하는 `slug` · `order` · `playPath`는 편집기에서 수정할 수 없습니다.
- **검증을 통과한 내용만 저장.** 실패하면 파일을 그대로 둡니다.
- **배포는 `content/`만.** 커밋 대상을 `content/`로 한정해(`src/lib/deploy-git.ts`의 `DEPLOY_PATHS`) 작업 중인 다른 변경이 딸려 올라가지 않습니다. 푸시가 거절되면 이유를 그대로 화면에 띄웁니다.
- **두 번 눌러야 나간다.** 한 번은 확인, 두 번째가 푸시입니다.

### 테스트

Vitest는 오락실의 입력 처리·기본 화면·실행 안내와 기존 기능을 검증합니다. 배포 경로 제한 · 새 파일 반영 · 푸시 거절 처리는
실제 임시 git 저장소를 만들어 확인하는 통합 테스트(`deploy.integration.test.ts`)로 검증합니다.

---

## AI 활용 방식

Claude Code로 개발했습니다. 기능마다 먼저 설계 문서와 실행 계획을 쓰고
(`docs/superpowers/specs/`, `docs/superpowers/plans/`), 계획에 **수정할 파일 · 보존할 기능 · 테스트 방법**을 적어
AI의 변경 범위를 묶었습니다. 결과는 테스트와 실제 화면을 함께 확인한 뒤 반영했습니다.

---

## 실행

```bash
npm install
npm run dev     # http://localhost:3000
npm test        # Vitest
npm run build   # 프로덕션 빌드
```

> **Node.js 22 LTS 권장.** Node 25 이상에서는 Node 내장 `localStorage`가 jsdom의 것을 가려
> `ThemeProvider` 테스트 3개가 실패합니다. 이때는 `NODE_OPTIONS=--no-experimental-webstorage npm test`로 실행합니다.

### 게임 추가

1. 웹 빌드를 `public/games/<slug>/`에 넣는다 (`index.html` 필수). Godot 4.3+는 웹 익스포트 시 **Thread Support를 끈다** (특수 헤더 불필요).
2. `content/games/<순번>-<slug>.json` 레코드를 만든다. `coverScene`은 `starfall | cave | pong | system` 중 하나.
3. `npm test` — 레지스트리 검증 통과 확인.
4. `src/lib/games.test.ts`의 playable 목록에 slug를 추가한다.
5. 푸시하면 Vercel이 자동 배포한다.

### 개발 서버 전용 페이지

| 경로 | 용도 |
|---|---|
| `/editor` | 게임 카트리지(제목 · 부제 · 설명 · 태그 · 커버)와 PLAYER 1 프로필 편집, 실제 컴포넌트 프리뷰, DEPLOY 버튼 |
| `/brand` | 프로필 · 파비콘 · 유튜브 배너 · 쇼츠 카드 · 포스트 템플릿을 실제 크기로 렌더해 PNG로 내보내기 (사이트와 팔레트·폰트 공유) |

### 테마

NIGHT(PICO-8 계열) / DMG(게임보이 4색) — 우상단 PALETTE SWAP. 선택은 `localStorage`의 `palette`에 저장됩니다.

---

## 구조

```
src/
  app/               Next.js App Router — 홈 · play · editor · brand · api(editor, deploy, game-editor)
  components/        Shelf · Hero · PlayFrame · Player1 · ThemeProvider …
  lib/               games 레지스트리 · editor · deploy(-git) · brand 렌더링 (DOM 비의존, 단위 테스트)
content/             게임 레코드 · 프로필 (편집기가 쓰는 유일한 대상)
public/games/        게임 웹 빌드
games-src/           Godot 프로젝트 원본
extension/           크롬 사이드 패널 확장 (npm 의존성 없음)
docs/superpowers/    설계 문서(specs) · 실행 계획(plans) · 플레이테스트 기록
```
