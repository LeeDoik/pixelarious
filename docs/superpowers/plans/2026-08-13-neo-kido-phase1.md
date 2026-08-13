# NEO_KIDO Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** NEO_KIDO — 픽셀 아케이드 컨셉의 개인 게임 배포/포트폴리오 사이트를 Next.js로 구현하고 Vercel에 배포 가능한 상태로 만든다.

**Architecture:** Next.js(App Router, 정적 생성) 단일 앱. 게임은 `content/games/*.json` 데이터 레코드로 등록되고 카트리지 목록은 이 데이터에서 렌더링된다. 게임 실행은 `/play/[slug]` 페이지의 iframe 임베드 패턴(Phase 2 외부 업로드와 동일 구조). 시각 기준은 리포지토리의 목업 `docs/superpowers/specs/2026-08-13-neo-kido-mockup.html`이며, CSS는 이 목업에서 추출해 사용한다.

**Tech Stack:** Next.js 15 + React 19 + TypeScript, vitest + @testing-library/react (jsdom), 순수 CSS(전역 스타일시트, 프레임워크 없음), Vercel 배포.

**Spec:** `docs/superpowers/specs/2026-08-13-neo-kido-design.md` (모든 요구사항의 원천)

## Global Constraints

모든 태스크에 적용된다. 스펙에서 그대로 옮긴 값:

- **팔레트 NIGHT(기본)**: bg `#141127`, bg-deep `#0C0A1C`, surface `#1D2B53`, text `#FFF1E8`, dim `#8E99D9`, accent `#FF77A8`, accent2 `#29ADFF`, gold `#FFEC27`. NIGHT에만 CRT 스캔라인 오버레이.
- **팔레트 DMG**: `#081820` / `#346856` / `#88C070` / `#E0F8D0` — 이 4색 외 사용 금지 (커버 아트 포함).
- 테마 상태: body 클래스 `dmg`, localStorage 키 `palette` (값 `night`|`dmg`), 재방문 시 유지, FOUC 방지.
- **픽셀 미학**: `border-radius` 금지, 하드 섀도(블러 0), 캔버스는 `image-rendering: pixelated`. 전환 효과는 `steps()` — 단 카트리지 확장만 예외적으로 `0.45s cubic-bezier(.22,.9,.3,1)`.
- **폰트**: Press Start 2P(영문 디스플레이) + 네오둥근모(한글/본문), woff2 자체 호스팅. 외부 CDN 의존 금지.
- **언어**: UI 라벨은 영어(SELECT GAME, PLAYER 1, OPEN, PLAY…), 게임 설명·소개는 한국어.
- **죽은 링크 금지**: `playPath`가 null이면 PLAY 버튼 대신 "NOT INSERTED" 표시. `playPath`가 있으면 해당 파일이 `public/` 아래 실제로 존재해야 함(로더가 검증). 준비 안 된 소셜 링크는 버튼 미표시.
- **호버 확장은 `@media (hover:hover) and (pointer:fine)`에서만** (터치 sticky-hover 방지). 터치/키보드는 `.open` 클래스 토글 + `aria-expanded`.
- `prefers-reduced-motion: reduce` 지원(타이핑 즉시 완료 등). ≤640px 모바일 레이아웃.
- 사이트 이름 표기는 항상 `NEO_KIDO` (언더스코어 포함).
- 작업 디렉토리 경로에 공백 포함(`2D PROJECT`) — 셸 명령에서 경로는 항상 따옴표로 감싼다. 셸은 PowerShell 기준.

## File Structure (최종)

```
package.json, tsconfig.json, next.config.ts, vitest.config.ts, .gitignore, README.md
scripts/extract-mockup-css.py        ← 목업에서 globals.css 추출(재실행 가능)
public/fonts/press-start-2p.woff2, neodgm.woff2
public/games/system-check/index.html ← 파이프라인 검증용 진단 카트리지
content/games/*.json                 ← 게임 = 데이터 레코드 (4개)
src/app/layout.tsx                   ← 폰트/메타데이터/테마 init 스크립트
src/app/page.tsx                     ← 홈(히어로+카트리지+PLAYER 1+푸터 조립)
src/app/globals.css                  ← 목업에서 추출한 디자인 시스템 전체
src/app/play/[slug]/page.tsx         ← iframe 게임 플레이어
src/lib/scenes.ts                    ← 절차적 커버 아트(순수 함수) + Palette/CoverScene 타입
src/lib/scenes.test.ts
src/lib/games.ts                     ← 게임 레지스트리 로더+검증 (서버 전용, fs 사용)
src/lib/games.test.ts
src/components/ThemeProvider.tsx     ← palette context
src/components/ThemeProvider.test.tsx (PaletteSwap 테스트 겸용)
src/components/PaletteSwap.tsx
src/components/CoverCanvas.tsx
src/components/CoverCanvas.test.tsx
src/components/Hero.tsx
src/components/Hero.test.tsx
src/components/Cartridge.tsx
src/components/Cartridge.test.tsx
src/components/EmptySlot.tsx
src/components/Player1.tsx
src/components/Footer.tsx
```

---

### Task 1: Next.js 스캐폴드 + 폰트 + 디자인 시스템 CSS + 레이아웃

**Files:**
- Create: `package.json`, `tsconfig.json`, `next.config.ts`, `vitest.config.ts`, `.gitignore`(수정 또는 생성), `scripts/extract-mockup-css.py`, `src/app/layout.tsx`, `src/app/page.tsx`(임시), `src/test-setup.ts`, `public/fonts/press-start-2p.woff2`, `public/fonts/neodgm.woff2`, `src/app/globals.css`(스크립트로 생성)

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-08-13-neo-kido-mockup.html`의 `<style>` 블록
- Produces: 이후 모든 태스크가 쓰는 전역 CSS 클래스(`.wrap .sec .sec-head .sec-sub .hero .cursor .u .scroll-hint .swap .lab .carts .cart .cart-strip .cart-no .cover .cart-title .kr .cart-hint .open-ic .close-ic .cart-detail .cart-detail-inner .desc .tags .btn .soon .slot-box .about .links .stat footer .coin`), CSS 변수(`--bg --bg-deep --surface --text --dim --accent --accent2 --gold --frame --shadow --btn-bg --btn-text --font-display --font-body`), 테마 init 스크립트(body 클래스 `dmg`)

- [ ] **Step 1: Node 버전 확인**

Run: `node -v`
Expected: `v20` 이상. 아니면 중단하고 Node 20+ 설치 요청.

- [ ] **Step 2: 프로젝트 설정 파일 작성**

`package.json`:
```json
{
  "name": "neo-kido",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "next": "^15.3.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@testing-library/dom": "^10.4.0",
    "@testing-library/react": "^16.2.0",
    "@types/node": "^22.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.3.0",
    "jsdom": "^26.0.0",
    "typescript": "^5.6.0",
    "vitest": "^3.0.0"
  }
}
```

`tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

`next.config.ts`:
```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {}

export default nextConfig
```

`vitest.config.ts`:
```ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import path from 'node:path'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    include: ['src/**/*.test.{ts,tsx}'],
    setupFiles: ['./src/test-setup.ts'],
    passWithNoTests: true,
  },
  resolve: {
    alias: { '@': path.resolve(__dirname, 'src') },
  },
})
```

`src/test-setup.ts` (jsdom에 없는 matchMedia 스텁):
```ts
import { vi } from 'vitest'

Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
})
```

`.gitignore` (기존 파일이 있으면 아래 항목을 추가, 없으면 생성):
```
node_modules/
.next/
out/
.vercel
*.tsbuildinfo
next-env.d.ts
```

- [ ] **Step 3: 의존성 설치**

Run: `npm install`
Expected: 오류 없이 완료. `node_modules/` 생성.

- [ ] **Step 4: 픽셀 폰트 다운로드**

Run (PowerShell):
```powershell
New-Item -ItemType Directory -Force "public\fonts" | Out-Null
curl.exe -sL -o "public\fonts\press-start-2p.woff2" "https://fonts.gstatic.com/s/pressstart2p/v15/e3t4euO8T-267oIAQAu6jDQyK3nVivM.woff2"
curl.exe -sL -o "public\fonts\neodgm.woff2" "https://cdn.jsdelivr.net/gh/neodgm/neodgm-webfont@latest/neodgm/neodgm.woff2"
Get-ChildItem "public\fonts"
```
Expected: `press-start-2p.woff2` 약 12KB, `neodgm.woff2` 약 38KB. 파일 첫 4바이트가 `wOF2`인지 의심되면 확인: `Get-Content "public\fonts\neodgm.woff2" -Encoding Byte -TotalCount 4` → `119 79 70 50`.

- [ ] **Step 5: 목업에서 globals.css 추출 스크립트 작성 및 실행**

`scripts/extract-mockup-css.py`:
```python
"""목업 HTML의 <style> 블록을 src/app/globals.css로 추출한다.
base64 인라인 폰트는 public/fonts/ 파일 참조로 교체한다.
목업이 갱신되면 재실행해서 CSS를 동기화할 수 있다."""
import re
import pathlib

src = pathlib.Path('docs/superpowers/specs/2026-08-13-neo-kido-mockup.html').read_text(encoding='utf-8')
css = re.search(r'<style>\n?(.*?)</style>', src, re.S).group(1)
css = re.sub(
    r"@font-face\{font-family:'PS2P';[^}]*\}",
    "@font-face{font-family:'PS2P';src:url('/fonts/press-start-2p.woff2') format('woff2');font-display:block}",
    css,
)
css = re.sub(
    r"@font-face\{font-family:'NeoDGM';[^}]*\}",
    "@font-face{font-family:'NeoDGM';src:url('/fonts/neodgm.woff2') format('woff2');font-display:block}",
    css,
)
out = pathlib.Path('src/app/globals.css')
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(css.strip() + '\n', encoding='utf-8')
print('globals.css written:', len(css), 'chars')
```

Run: `python scripts/extract-mockup-css.py`
Expected: `globals.css written: ...` 출력. `src/app/globals.css`를 열어 확인: (1) `@font-face` 2개가 `/fonts/...woff2` URL을 참조, (2) base64 문자열이 없음, (3) `:root`에 NIGHT 팔레트, `body.dmg`에 DMG 팔레트 존재.

- [ ] **Step 6: 레이아웃과 임시 홈 작성**

`src/app/layout.tsx`:
```tsx
import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'NEO_KIDO',
  description: '1인 개발자 LeeDoik의 게임을 브라우저에서 바로 플레이하는 픽셀 아케이드',
}

const themeInit =
  "try{if(localStorage.getItem('palette')==='dmg')document.body.classList.add('dmg')}catch(e){}"

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body suppressHydrationWarning>
        <script dangerouslySetInnerHTML={{ __html: themeInit }} />
        {children}
      </body>
    </html>
  )
}
```
(테마 init 스크립트는 body 최상단에서 하이드레이션 전에 실행되어 FOUC를 막는다. ThemeProvider는 Task 3에서 감싼다.)

`src/app/page.tsx` (Task 7에서 교체될 임시 페이지):
```tsx
export default function Home() {
  return (
    <main className="wrap sec">
      <h1 className="sec-head">
        <span className="deco">►</span> NEO_KIDO — UNDER CONSTRUCTION
      </h1>
    </main>
  )
}
```

- [ ] **Step 7: 빌드와 테스트 러너 검증**

Run: `npm run build`
Expected: 컴파일 성공, `/` 정적 생성. (첫 실행 시 `next-env.d.ts` 자동 생성됨.)

Run: `npm test`
Expected: "No test files found" 경고와 함께 종료 코드 0 (`passWithNoTests`).

Run: `npm run dev` 후 http://localhost:3000 열기.
Expected: 어두운 인디고 배경(#141127) + 스캔라인 위에 픽셀 폰트 제목. 폰트가 네모(□)로 보이면 Step 4-5 재확인. 확인 후 dev 서버 종료.

- [ ] **Step 8: Commit**

```powershell
git add package.json tsconfig.json next.config.ts vitest.config.ts .gitignore scripts src public/fonts package-lock.json
git commit -m "feat: scaffold Next.js app with pixel design system from mockup"
```

---

### Task 2: 게임 레지스트리 (게임 = 데이터 레코드)

**Files:**
- Create: `src/lib/games.ts`, `src/lib/games.test.ts`, `content/games/00-system-check.json`, `content/games/01-starfall-drift.json`, `content/games/02-down-the-cave.json`, `content/games/03-pixel-pong-exe.json`, `public/games/system-check/index.html`
- 참고: `CoverScene` 타입은 Task 4의 `src/lib/scenes.ts`가 원천이지만, 이 태스크에서 먼저 최소 형태로 만든다(아래 Step 3).

**Interfaces:**
- Produces:
  - `interface Game { slug: string; order: number; title: string; subtitle?: string; description: string; tags: string[]; coverScene: CoverScene; playPath: string | null }`
  - `getGames(): Game[]` — order 오름차순 정렬, 전체 검증(슬러그 형식/중복, playPath 파일 존재)
  - `getGame(slug: string): Game | undefined`
  - `src/lib/scenes.ts`의 `export type CoverScene = 'starfall' | 'cave' | 'pong' | 'system'`
- 주의: `games.ts`는 `node:fs`를 사용하므로 **서버 컴포넌트에서만 import** (클라이언트 컴포넌트 금지).

- [ ] **Step 1: 실패하는 테스트 작성**

`src/lib/games.test.ts`:
```ts
import { describe, it, expect } from 'vitest'
import { getGames, getGame } from './games'

describe('games registry', () => {
  it('loads all game records without validation errors', () => {
    expect(getGames().length).toBeGreaterThanOrEqual(4)
  })

  it('returns games sorted by order ascending', () => {
    const orders = getGames().map((g) => g.order)
    expect(orders).toEqual([...orders].sort((a, b) => a - b))
  })

  it('has unique slugs', () => {
    const slugs = getGames().map((g) => g.slug)
    expect(new Set(slugs).size).toBe(slugs.length)
  })

  it('system-check cartridge is playable', () => {
    const g = getGame('system-check')
    expect(g?.playPath).toBe('/games/system-check/index.html')
  })

  it('returns undefined for unknown slug', () => {
    expect(getGame('no-such-game')).toBeUndefined()
  })
})
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `npm test`
Expected: FAIL — `Cannot find module './games'` 계열 오류.

- [ ] **Step 3: 씬 타입 파일 최소 생성**

`src/lib/scenes.ts` (Task 4에서 구현이 추가된다 — 지금은 타입만):
```ts
export type CoverScene = 'starfall' | 'cave' | 'pong' | 'system'
export const COVER_SCENES: CoverScene[] = ['starfall', 'cave', 'pong', 'system']
```

- [ ] **Step 4: 레지스트리 구현**

`src/lib/games.ts`:
```ts
import fs from 'node:fs'
import path from 'node:path'
import { COVER_SCENES, type CoverScene } from './scenes'

export interface Game {
  slug: string
  order: number
  title: string
  subtitle?: string
  description: string
  tags: string[]
  coverScene: CoverScene
  playPath: string | null
}

const GAMES_DIR = path.join(process.cwd(), 'content', 'games')

function validate(raw: Record<string, unknown>, file: string): Game {
  const fail = (msg: string): never => {
    throw new Error(`${file}: ${msg}`)
  }
  if (typeof raw.slug !== 'string' || !/^[a-z0-9-]+$/.test(raw.slug)) fail('slug must be kebab-case')
  if (typeof raw.order !== 'number') fail('order must be a number')
  if (typeof raw.title !== 'string' || raw.title.length === 0) fail('title required')
  if (raw.subtitle !== undefined && typeof raw.subtitle !== 'string') fail('subtitle must be a string')
  if (typeof raw.description !== 'string' || raw.description.length === 0) fail('description required')
  if (!Array.isArray(raw.tags) || raw.tags.some((t) => typeof t !== 'string')) fail('tags must be string[]')
  if (!COVER_SCENES.includes(raw.coverScene as CoverScene))
    fail(`coverScene must be one of: ${COVER_SCENES.join(', ')}`)
  if (raw.playPath !== null && typeof raw.playPath !== 'string') fail('playPath must be string or null')
  if (typeof raw.playPath === 'string') {
    const abs = path.join(process.cwd(), 'public', raw.playPath)
    if (!fs.existsSync(abs)) fail(`playPath file missing: ${raw.playPath}`)
  }
  return raw as unknown as Game
}

export function getGames(): Game[] {
  const files = fs.readdirSync(GAMES_DIR).filter((f) => f.endsWith('.json'))
  const games = files.map((f) =>
    validate(JSON.parse(fs.readFileSync(path.join(GAMES_DIR, f), 'utf-8')), f),
  )
  const seen = new Set<string>()
  for (const g of games) {
    if (seen.has(g.slug)) throw new Error(`duplicate slug: ${g.slug}`)
    seen.add(g.slug)
  }
  return games.sort((a, b) => a.order - b.order)
}

export function getGame(slug: string): Game | undefined {
  return getGames().find((g) => g.slug === slug)
}
```

- [ ] **Step 5: 게임 레코드 4개 작성**

`content/games/01-starfall-drift.json`:
```json
{
  "slug": "starfall-drift",
  "order": 10,
  "title": "STARFALL DRIFT",
  "description": "중력을 뒤집으며 별 사이를 활강하는 우주 플랫포머. 한 번의 점프로 궤도를 갈아타고, 떨어지는 별을 따라 스테이지 끝까지 표류하세요.",
  "tags": ["GODOT 4", "2D", "PLATFORMER", "WEB"],
  "coverScene": "starfall",
  "playPath": null
}
```

`content/games/02-down-the-cave.json`:
```json
{
  "slug": "down-the-cave",
  "order": 20,
  "title": "DOWN THE CAVE",
  "subtitle": "동굴 아래로",
  "description": "곡괭이 하나로 시작하는 로그라이크 채굴 어드벤처. 내려갈수록 어두워지고, 어두울수록 반짝이는 것이 많아집니다. 램프 기름이 떨어지기 전에 돌아올 수 있을까요?",
  "tags": ["GODOT 4", "2D", "ROGUELIKE", "WEB"],
  "coverScene": "cave",
  "playPath": null
}
```

`content/games/03-pixel-pong-exe.json`:
```json
{
  "slug": "pixel-pong-exe",
  "order": 30,
  "title": "PIXEL PONG.EXE",
  "description": "하루 만에 만든 아케이드 퐁 변형. 공이 벽에 닿을 때마다 규칙이 하나씩 바뀝니다. 최고 기록은 아직 개발자 본인이 갖고 있습니다 — 깨 보세요.",
  "tags": ["GODOT 4", "2D", "ARCADE", "1-DAY JAM"],
  "coverScene": "pong",
  "playPath": null
}
```

`content/games/00-system-check.json`:
```json
{
  "slug": "system-check",
  "order": 90,
  "title": "SYSTEM CHECK",
  "subtitle": "동작 확인용 카트리지",
  "description": "NEO_KIDO 배포 파이프라인이 정상 작동하는지 확인하는 진단 카트리지입니다. 실제 게임이 꽂히면 이 카트리지는 빠집니다.",
  "tags": ["SYSTEM", "WEB"],
  "coverScene": "system",
  "playPath": "/games/system-check/index.html"
}
```
(위 3종은 스펙 §6대로 레이아웃 검증용 플레이스홀더 — `playPath: null`. 실제 게임 추가 = json 1개 + `public/games/<slug>/` 폴더 1개.)

- [ ] **Step 6: 진단 카트리지 페이지 작성**

`public/games/system-check/index.html`:
```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>SYSTEM CHECK</title>
<style>
  body{margin:0;background:#0C0A1C;color:#FFF1E8;font-family:'Courier New',monospace;
       display:flex;align-items:center;justify-content:center;min-height:100vh}
  pre{font-size:16px;line-height:1.8;margin:0}
  .ok{color:#29ADFF}
  .gold{color:#FFEC27}
</style>
</head>
<body>
<pre id="log">NEO_KIDO SYSTEM CHECK
---------------------
VIDEO ........ <span class="ok">OK</span>
AUDIO ........ <span class="ok">OK</span>
INPUT ........ press any key
<span class="gold">█</span></pre>
<script>
  addEventListener('keydown', function (e) {
    document.getElementById('log').innerHTML =
      'NEO_KIDO SYSTEM CHECK\n---------------------\nVIDEO ........ <span class="ok">OK</span>\nAUDIO ........ <span class="ok">OK</span>\nINPUT ........ <span class="ok">OK</span> [' + e.key + ']\n\nALL SYSTEMS GO. INSERT REAL GAME.\n<span class="gold">█</span>';
  });
</script>
</body>
</html>
```
(키 입력 반응은 "iframe이 키보드 포커스를 받는가"를 검증한다 — Godot 웹 게임이 요구하는 조건.)

- [ ] **Step 7: 테스트 통과 확인**

Run: `npm test`
Expected: PASS — games registry 5개 테스트 모두 통과.

- [ ] **Step 8: Commit**

```powershell
git add src/lib content public/games
git commit -m "feat: add game registry with validated data records and system-check cartridge"
```

---

### Task 3: 테마 시스템 (ThemeProvider + PaletteSwap)

**Files:**
- Create: `src/components/ThemeProvider.tsx`, `src/components/PaletteSwap.tsx`, `src/components/ThemeProvider.test.tsx`
- Modify: `src/app/layout.tsx` (ThemeProvider로 children 감싸기)

**Interfaces:**
- Consumes: `src/lib/scenes.ts`의 `Palette` 타입 (이 태스크에서 추가)
- Produces:
  - `src/lib/scenes.ts`에 `export type Palette = 'night' | 'dmg'` 추가
  - `ThemeProvider({ children })` — context provider
  - `usePalette(): { palette: Palette; toggle: () => void }` — Provider 밖에서는 `{ palette: 'night', toggle: no-op }` 기본값 (테스트에서 Provider 없이도 컴포넌트 렌더 가능)
  - `PaletteSwap()` — 우상단 고정 토글 버튼 (CSS 클래스 `.swap`은 Task 1의 globals.css에 이미 존재)

- [ ] **Step 1: 실패하는 테스트 작성**

`src/components/ThemeProvider.test.tsx`:
```tsx
import { describe, it, expect, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup } from '@testing-library/react'
import { ThemeProvider } from './ThemeProvider'
import { PaletteSwap } from './PaletteSwap'

afterEach(() => {
  cleanup()
  document.body.classList.remove('dmg')
  localStorage.clear()
})

describe('theme system', () => {
  it('toggles the dmg body class and persists the choice', () => {
    render(
      <ThemeProvider>
        <PaletteSwap />
      </ThemeProvider>,
    )
    const btn = screen.getByRole('button', { name: /PALETTE/ })
    fireEvent.click(btn)
    expect(document.body.classList.contains('dmg')).toBe(true)
    expect(localStorage.getItem('palette')).toBe('dmg')
    fireEvent.click(btn)
    expect(document.body.classList.contains('dmg')).toBe(false)
    expect(localStorage.getItem('palette')).toBe('night')
  })

  it('restores a saved dmg palette on mount', () => {
    localStorage.setItem('palette', 'dmg')
    render(
      <ThemeProvider>
        <PaletteSwap />
      </ThemeProvider>,
    )
    expect(document.body.classList.contains('dmg')).toBe(true)
  })
})
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `npm test`
Expected: FAIL — `Cannot find module './ThemeProvider'`.

- [ ] **Step 3: 구현**

`src/lib/scenes.ts`에 추가:
```ts
export type Palette = 'night' | 'dmg'
```

`src/components/ThemeProvider.tsx`:
```tsx
'use client'

import { createContext, useContext, useEffect, useState } from 'react'
import type { Palette } from '@/lib/scenes'

const ThemeContext = createContext<{ palette: Palette; toggle: () => void }>({
  palette: 'night',
  toggle: () => {},
})

function readSaved(): Palette {
  if (typeof window === 'undefined') return 'night'
  try {
    return localStorage.getItem('palette') === 'dmg' ? 'dmg' : 'night'
  } catch {
    return 'night'
  }
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [palette, setPalette] = useState<Palette>(readSaved)

  useEffect(() => {
    document.body.classList.toggle('dmg', palette === 'dmg')
    try {
      localStorage.setItem('palette', palette)
    } catch {}
  }, [palette])

  const toggle = () => setPalette((p) => (p === 'night' ? 'dmg' : 'night'))

  return <ThemeContext.Provider value={{ palette, toggle }}>{children}</ThemeContext.Provider>
}

export function usePalette() {
  return useContext(ThemeContext)
}
```

`src/components/PaletteSwap.tsx`:
```tsx
'use client'

import { useEffect, useState } from 'react'
import { usePalette } from './ThemeProvider'

export function PaletteSwap() {
  const { palette, toggle } = usePalette()
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])
  // SSR은 항상 NIGHT로 그리므로, 마운트 전에는 라벨을 NIGHT로 고정해 hydration mismatch를 막는다
  const label = mounted && palette === 'dmg' ? 'DMG' : 'NIGHT'
  return (
    <button className="swap" type="button" onClick={toggle}>
      PALETTE: <span className="lab">{label}</span> ▸ SWAP
    </button>
  )
}
```

`src/app/layout.tsx`의 body 내부를 다음으로 교체:
```tsx
import { ThemeProvider } from '@/components/ThemeProvider'
```
```tsx
      <body suppressHydrationWarning>
        <script dangerouslySetInnerHTML={{ __html: themeInit }} />
        <ThemeProvider>{children}</ThemeProvider>
      </body>
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `npm test`
Expected: PASS — theme system 2개 포함 전체 통과.

- [ ] **Step 5: Commit**

```powershell
git add src/components src/lib/scenes.ts src/app/layout.tsx
git commit -m "feat: add palette theme system with persistence"
```

---

### Task 4: 절차적 커버 아트 (scenes + CoverCanvas)

**Files:**
- Modify: `src/lib/scenes.ts` (drawScene 구현 추가)
- Create: `src/lib/scenes.test.ts`, `src/components/CoverCanvas.tsx`, `src/components/CoverCanvas.test.tsx`

**Interfaces:**
- Consumes: `Palette`, `CoverScene` (scenes.ts), `usePalette()` (Task 3)
- Produces:
  - `drawScene(canvas: { width: number; height: number; getContext(id: '2d'): CanvasRenderingContext2D | null }, scene: CoverScene, palette: Palette): void` — 순수 함수, ctx가 null이면 조용히 반환
  - `PALETTES: Record<Palette, Record<CoverScene, { sky: string; far: string; star: string; hi: string; obj: string; obj2: string }>>`
  - `CoverCanvas({ scene }: { scene: CoverScene })` — 100×42 캔버스, 팔레트 변경 시 자동 재드로잉, `className="cover"` `aria-hidden`

- [ ] **Step 1: 실패하는 테스트 작성**

`src/lib/scenes.test.ts`:
```ts
import { describe, it, expect } from 'vitest'
import { drawScene, COVER_SCENES } from './scenes'
import type { Palette } from './scenes'

function fakeCanvas() {
  const calls: [string, number, number, number, number][] = []
  const ctx = {
    fillStyle: '',
    fillRect(x: number, y: number, w: number, h: number) {
      calls.push([String(this.fillStyle), x, y, w, h])
    },
  }
  return {
    canvas: { width: 100, height: 42, getContext: () => ctx } as never,
    calls,
  }
}

describe('drawScene', () => {
  it('draws every scene in every palette', () => {
    for (const palette of ['night', 'dmg'] as Palette[]) {
      for (const scene of COVER_SCENES) {
        const { canvas, calls } = fakeCanvas()
        drawScene(canvas, scene, palette)
        expect(calls.length, `${palette}/${scene}`).toBeGreaterThan(5)
      }
    }
  })

  it('dmg palette uses only the four Game Boy colors', () => {
    const allowed = new Set(['#081820', '#346856', '#88C070', '#E0F8D0'])
    for (const scene of COVER_SCENES) {
      const { canvas, calls } = fakeCanvas()
      drawScene(canvas, scene, 'dmg')
      for (const [color] of calls) {
        expect(allowed.has(color), `${scene} used ${color}`).toBe(true)
      }
    }
  })

  it('is deterministic (same seed, same output)', () => {
    const a = fakeCanvas()
    const b = fakeCanvas()
    drawScene(a.canvas, 'cave', 'night')
    drawScene(b.canvas, 'cave', 'night')
    expect(a.calls).toEqual(b.calls)
  })
})
```

`src/components/CoverCanvas.test.tsx`:
```tsx
import { describe, it, expect, afterEach } from 'vitest'
import { render, cleanup } from '@testing-library/react'
import { CoverCanvas } from './CoverCanvas'

afterEach(cleanup)

describe('CoverCanvas', () => {
  it('renders a pixelated cover canvas without crashing in jsdom', () => {
    // jsdom의 getContext는 null을 반환한다 — drawScene의 null 가드 경로 검증
    const { container } = render(<CoverCanvas scene="starfall" />)
    const canvas = container.querySelector('canvas.cover')
    expect(canvas).not.toBeNull()
    expect(canvas?.getAttribute('width')).toBe('100')
    expect(canvas?.getAttribute('aria-hidden')).toBe('true')
  })
})
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `npm test`
Expected: FAIL — `drawScene`이 export되지 않음 / `Cannot find module './CoverCanvas'`.

- [ ] **Step 3: 구현**

`src/lib/scenes.ts` 전체를 다음으로 교체 (기존 타입 유지 + 구현 추가):
```ts
export type CoverScene = 'starfall' | 'cave' | 'pong' | 'system'
export const COVER_SCENES: CoverScene[] = ['starfall', 'cave', 'pong', 'system']
export type Palette = 'night' | 'dmg'

interface ScenePalette {
  sky: string
  far: string
  star: string
  hi: string
  obj: string
  obj2: string
}

export const PALETTES: Record<Palette, Record<CoverScene, ScenePalette>> = {
  night: {
    starfall: { sky: '#0C0A1C', far: '#1D2B53', star: '#FFF1E8', hi: '#FFEC27', obj: '#FF77A8', obj2: '#29ADFF' },
    cave: { sky: '#0C0A1C', far: '#1D2B53', star: '#8E99D9', hi: '#FFEC27', obj: '#29ADFF', obj2: '#FF77A8' },
    pong: { sky: '#0C0A1C', far: '#1D2B53', star: '#8E99D9', hi: '#FFEC27', obj: '#FFF1E8', obj2: '#FF77A8' },
    system: { sky: '#0C0A1C', far: '#1D2B53', star: '#8E99D9', hi: '#FFEC27', obj: '#FF77A8', obj2: '#29ADFF' },
  },
  dmg: {
    starfall: { sky: '#081820', far: '#346856', star: '#E0F8D0', hi: '#E0F8D0', obj: '#88C070', obj2: '#E0F8D0' },
    cave: { sky: '#081820', far: '#346856', star: '#88C070', hi: '#E0F8D0', obj: '#88C070', obj2: '#E0F8D0' },
    pong: { sky: '#081820', far: '#346856', star: '#88C070', hi: '#E0F8D0', obj: '#E0F8D0', obj2: '#88C070' },
    system: { sky: '#081820', far: '#346856', star: '#88C070', hi: '#E0F8D0', obj: '#88C070', obj2: '#E0F8D0' },
  },
}

const SEEDS: Record<CoverScene, number> = { starfall: 7, cave: 23, pong: 41, system: 77 }

/** mulberry32 시드 기반 PRNG — 커버가 렌더마다 같게 유지된다 */
function rng(seed: number) {
  return function () {
    seed |= 0
    seed = (seed + 0x6d2b79f5) | 0
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

type MinimalCanvas = {
  width: number
  height: number
  getContext(id: '2d'): CanvasRenderingContext2D | null
}

export function drawScene(canvas: MinimalCanvas, scene: CoverScene, palette: Palette): void {
  const ctx = canvas.getContext('2d')
  if (!ctx) return
  const p = PALETTES[palette][scene]
  const W = canvas.width
  const H = canvas.height
  const r = rng(SEEDS[scene])
  const px = (x: number, y: number, w: number, h: number, c: string) => {
    ctx.fillStyle = c
    ctx.fillRect(x, y, w, h)
  }

  px(0, 0, W, H, p.sky)

  if (scene === 'starfall') {
    for (let i = 0; i < 46; i++) px((r() * W) | 0, (r() * H) | 0, 1, 1, r() < 0.18 ? p.hi : p.star)
    px(70, 6, 14, 14, p.obj2)
    px(72, 8, 10, 10, p.far)
    px(74, 10, 6, 6, p.obj2)
    px(64, 12, 26, 2, p.obj2)
    px(24, 22, 8, 4, p.obj)
    px(26, 20, 4, 2, p.obj)
    px(22, 24, 2, 2, p.hi)
    px(32, 24, 2, 2, p.hi)
    for (let x = 0; x < W; x += 2) px(x, H - 3 - ((Math.sin(x * 0.3) * 2) | 0), 2, 6, p.far)
  }

  if (scene === 'cave') {
    for (let x = 0; x < W; x += 4) px(x, 0, 4, 4 + ((r() * 10) | 0), p.far)
    for (let x = 0; x < W; x += 4) {
      const d = 3 + ((r() * 8) | 0)
      px(x, H - d, 4, d, p.far)
    }
    for (let i = 0; i < 12; i++) px((r() * W) | 0, 14 + ((r() * (H - 24)) | 0), 2, 2, r() < 0.5 ? p.obj : p.obj2)
    px(46, 24, 6, 8, p.hi)
    px(48, 20, 2, 4, p.hi)
  }

  if (scene === 'pong') {
    for (let y = 2; y < H; y += 6) px(W / 2 - 1, y, 2, 3, p.far)
    px(6, 10, 3, 12, p.obj)
    px(W - 9, 20, 3, 12, p.obj)
    px(58, 14, 3, 3, p.hi)
    for (let i = 0; i < 10; i++) px((r() * W) | 0, (r() * H) | 0, 1, 1, p.star)
  }

  if (scene === 'system') {
    // TV 컬러바 테스트 패턴
    const bars = [p.obj, p.obj2, p.hi, p.far, p.star]
    const bw = Math.ceil(W / bars.length)
    bars.forEach((c, i) => px(i * bw, 0, bw, H - 8, c))
    px(0, H - 8, W, 8, p.far)
    for (let x = 2; x < W; x += 6) px(x, H - 6, 4, 4, p.sky)
  }
}
```

`src/components/CoverCanvas.tsx`:
```tsx
'use client'

import { useEffect, useRef } from 'react'
import { drawScene, type CoverScene } from '@/lib/scenes'
import { usePalette } from './ThemeProvider'

export function CoverCanvas({ scene }: { scene: CoverScene }) {
  const ref = useRef<HTMLCanvasElement>(null)
  const { palette } = usePalette()

  useEffect(() => {
    if (ref.current) drawScene(ref.current, scene, palette)
  }, [scene, palette])

  return <canvas ref={ref} className="cover" width={100} height={42} aria-hidden="true" />
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `npm test`
Expected: PASS — scenes 3개 + CoverCanvas 1개 포함 전체 통과.

- [ ] **Step 5: Commit**

```powershell
git add src/lib/scenes.ts src/lib/scenes.test.ts src/components/CoverCanvas.tsx src/components/CoverCanvas.test.tsx
git commit -m "feat: add procedural pixel cover art with palette-aware redraw"
```

---

### Task 5: 타이핑 히어로

**Files:**
- Create: `src/components/Hero.tsx`, `src/components/Hero.test.tsx`

**Interfaces:**
- Produces: `Hero()` — 클라이언트 컴포넌트. `NEO_KIDO`를 600ms 대기 후 글자당 95ms로 타이핑, 완료 250ms 후 스크롤 힌트 표시 + 언더스코어 골드(`.u`). reduced-motion이면 즉시 완료. CSS 클래스 `.hero .cursor .u .scroll-hint .arr`는 globals.css에 이미 존재.

- [ ] **Step 1: 실패하는 테스트 작성**

`src/components/Hero.test.tsx`:
```tsx
import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, act, cleanup } from '@testing-library/react'
import { Hero } from './Hero'

afterEach(() => {
  cleanup()
  vi.useRealTimers()
})

describe('Hero', () => {
  it('types out NEO_KIDO over time', () => {
    vi.useFakeTimers()
    render(<Hero />)
    const h1 = screen.getByRole('heading', { level: 1 })
    expect(h1.textContent).not.toContain('NEO_KIDO')
    act(() => {
      vi.advanceTimersByTime(600 + 95 * 8 + 300)
    })
    expect(h1.textContent).toContain('NEO_KIDO')
  })

  it('shows the full name immediately when reduced motion is preferred', () => {
    vi.mocked(window.matchMedia).mockReturnValueOnce({
      matches: true,
      media: '(prefers-reduced-motion: reduce)',
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    } as unknown as MediaQueryList)
    render(<Hero />)
    expect(screen.getByRole('heading', { level: 1 }).textContent).toContain('NEO_KIDO')
  })
})
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `npm test`
Expected: FAIL — `Cannot find module './Hero'`.

- [ ] **Step 3: 구현**

`src/components/Hero.tsx`:
```tsx
'use client'

import { useEffect, useState } from 'react'

const SITE_NAME = 'NEO_KIDO'
const START_DELAY_MS = 600
const CHAR_DELAY_MS = 95
const FINISH_DELAY_MS = 250

export function Hero() {
  const [count, setCount] = useState(0)
  const [done, setDone] = useState(false)

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setCount(SITE_NAME.length)
      setDone(true)
      return
    }
    let i = 0
    let timer: ReturnType<typeof setTimeout>
    const tick = () => {
      i += 1
      setCount(i)
      timer =
        i < SITE_NAME.length
          ? setTimeout(tick, CHAR_DELAY_MS)
          : setTimeout(() => setDone(true), FINISH_DELAY_MS)
    }
    timer = setTimeout(tick, START_DELAY_MS)
    return () => clearTimeout(timer)
  }, [])

  return (
    <header className="hero">
      <h1>
        <span>
          {SITE_NAME.slice(0, count)
            .split('')
            .map((ch, i) => (
              <span key={i} className={done && ch === '_' ? 'u' : undefined}>
                {ch}
              </span>
            ))}
        </span>
        <span className="cursor">█</span>
      </h1>
      <div className={done ? 'scroll-hint show' : 'scroll-hint'}>
        SCROLL TO SELECT<span className="arr">▼</span>
      </div>
    </header>
  )
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `npm test`
Expected: PASS — Hero 2개 포함 전체 통과.

- [ ] **Step 5: Commit**

```powershell
git add src/components/Hero.tsx src/components/Hero.test.tsx
git commit -m "feat: add typing hero with reduced-motion support"
```

---

### Task 6: 카트리지 컴포넌트

**Files:**
- Create: `src/components/Cartridge.tsx`, `src/components/EmptySlot.tsx`, `src/components/Cartridge.test.tsx`
- Modify: `src/app/globals.css` (NOT INSERTED 스타일 추가)

**Interfaces:**
- Consumes: `Game` 타입(Task 2, 데이터는 props로 받음 — 이 컴포넌트는 클라이언트이므로 `getGames()` 직접 호출 금지), `CoverCanvas`(Task 4)
- Produces:
  - `Cartridge({ game, index }: { game: Game; index: number })` — 클릭/Enter/Space로 `.open` 토글, `aria-expanded` 동기화. `playPath` 있으면 `/play/<slug>` PLAY 링크, null이면 "NOT INSERTED"
  - `EmptySlot({ index }: { index: number })` — 빈 슬롯(정적)

- [ ] **Step 1: 실패하는 테스트 작성**

`src/components/Cartridge.test.tsx`:
```tsx
import { describe, it, expect, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup } from '@testing-library/react'
import { Cartridge } from './Cartridge'
import type { Game } from '@/lib/games'

afterEach(cleanup)

const base: Game = {
  slug: 'starfall-drift',
  order: 10,
  title: 'STARFALL DRIFT',
  description: '중력을 뒤집으며 별 사이를 활강하는 우주 플랫포머.',
  tags: ['GODOT 4', '2D'],
  coverScene: 'starfall',
  playPath: null,
}

describe('Cartridge', () => {
  it('toggles open state on click with aria-expanded', () => {
    render(<Cartridge game={base} index={0} />)
    const strip = screen.getByRole('button')
    expect(strip.getAttribute('aria-expanded')).toBe('false')
    fireEvent.click(strip)
    expect(strip.getAttribute('aria-expanded')).toBe('true')
    fireEvent.click(strip)
    expect(strip.getAttribute('aria-expanded')).toBe('false')
  })

  it('toggles with the keyboard (Enter)', () => {
    render(<Cartridge game={base} index={0} />)
    const strip = screen.getByRole('button')
    fireEvent.keyDown(strip, { key: 'Enter' })
    expect(strip.getAttribute('aria-expanded')).toBe('true')
  })

  it('shows NOT INSERTED instead of a dead link when playPath is null', () => {
    render(<Cartridge game={base} index={0} />)
    expect(screen.getByText('NOT INSERTED')).toBeDefined()
    expect(screen.queryByText('▶ PLAY')).toBeNull()
  })

  it('links PLAY to /play/<slug> when playPath exists', () => {
    render(
      <Cartridge game={{ ...base, slug: 'system-check', playPath: '/games/system-check/index.html' }} index={3} />,
    )
    const play = screen.getByText('▶ PLAY').closest('a')
    expect(play?.getAttribute('href')).toBe('/play/system-check')
  })

  it('renders the 1-based zero-padded slot number', () => {
    render(<Cartridge game={base} index={0} />)
    expect(screen.getByText('01')).toBeDefined()
  })
})
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `npm test`
Expected: FAIL — `Cannot find module './Cartridge'`.

- [ ] **Step 3: 구현**

`src/components/Cartridge.tsx`:
```tsx
'use client'

import { useState } from 'react'
import Link from 'next/link'
import type { Game } from '@/lib/games'
import { CoverCanvas } from './CoverCanvas'

export function Cartridge({ game, index }: { game: Game; index: number }) {
  const [open, setOpen] = useState(false)
  const toggle = () => setOpen((o) => !o)

  return (
    <article className={open ? 'cart open' : 'cart'}>
      <div
        className="cart-strip"
        role="button"
        tabIndex={0}
        aria-expanded={open}
        onClick={toggle}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            toggle()
          }
        }}
      >
        <span className="cart-no">{String(index + 1).padStart(2, '0')}</span>
        <CoverCanvas scene={game.coverScene} />
        <h3 className="cart-title">
          {game.title}
          {game.subtitle && <span className="kr">{game.subtitle}</span>}
        </h3>
        <span className="cart-hint">
          <span className="open-ic">▼ OPEN</span>
          <span className="close-ic">▲</span>
        </span>
      </div>
      <div className="cart-detail">
        <div className="cart-detail-inner">
          <div>
            <p className="desc">{game.description}</p>
            <ul className="tags">
              {game.tags.map((t) => (
                <li key={t}>{t}</li>
              ))}
            </ul>
          </div>
          {game.playPath ? (
            <Link className="btn" href={`/play/${game.slug}`}>
              ▶ PLAY
            </Link>
          ) : (
            <span className="btn not-inserted" aria-disabled="true">
              NOT INSERTED
            </span>
          )}
        </div>
      </div>
    </article>
  )
}
```

`src/components/EmptySlot.tsx`:
```tsx
export function EmptySlot({ index }: { index: number }) {
  return (
    <article className="cart soon">
      <div className="cart-strip">
        <span className="cart-no">{String(index + 1).padStart(2, '0')}</span>
        <div className="slot-box">EMPTY SLOT</div>
        <h3 className="cart-title">
          NEW GAME +<span className="kr">다음 게임 제작 중…</span>
        </h3>
        <span className="cart-hint"></span>
      </div>
      <div className="cart-detail">
        <div></div>
      </div>
    </article>
  )
}
```

`src/app/globals.css` 끝에 추가:
```css
/* not-inserted state — 죽은 링크 대신 표시 (스펙 §4.3) */
.btn.not-inserted{
  background:var(--surface); color:var(--dim); border-color:var(--dim);
  box-shadow:5px 5px 0 var(--shadow); cursor:default;
}
.btn.not-inserted:hover{transform:none; box-shadow:5px 5px 0 var(--shadow)}
.btn.not-inserted:active{transform:none; box-shadow:5px 5px 0 var(--shadow)}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `npm test`
Expected: PASS — Cartridge 5개 포함 전체 통과.

- [ ] **Step 5: Commit**

```powershell
git add src/components/Cartridge.tsx src/components/EmptySlot.tsx src/components/Cartridge.test.tsx src/app/globals.css
git commit -m "feat: add cartridge banner with expand interaction and empty slot"
```

---

### Task 7: 홈 페이지 조립 (PLAYER 1 + 푸터 포함)

**Files:**
- Create: `src/components/Player1.tsx`, `src/components/Footer.tsx`
- Modify: `src/app/page.tsx` (임시 페이지 교체)

**Interfaces:**
- Consumes: `getGames()`(서버, Task 2), `Hero`(Task 5), `Cartridge`/`EmptySlot`(Task 6), `PaletteSwap`(Task 3)
- Produces: 완성된 홈 페이지. `Player1()`, `Footer()` — 정적 컴포넌트.

- [ ] **Step 1: 컴포넌트 작성**

`src/components/Player1.tsx`:
```tsx
const LINKS: { label: string; href: string }[] = [
  { label: 'EMAIL', href: 'mailto:lee253628@gmail.com' },
  // 준비되면 주석 해제 (죽은 링크 금지 — 스펙 §4.3):
  // { label: 'GITHUB', href: 'https://github.com/<계정>' },
  // { label: 'ITCH.IO', href: 'https://<계정>.itch.io' },
]

const BADGES = ['ENGINE: GODOT 4', 'NEXT: UNITY 3D', 'LOCATION: SEOUL']

export function Player1() {
  return (
    <section className="sec" id="about">
      <h2 className="sec-head">
        <span className="deco">►</span> PLAYER 1
      </h2>
      <div className="about">
        <p>
          안녕하세요, 1인 게임 개발자 <b>LeeDoik</b>입니다. Godot 엔진으로 2D 게임을 만들어
          이곳에서 바로 플레이할 수 있게 배포합니다. 다음 목표는 Unity로 만드는 첫 3D
          게임입니다. 게임 제작 의뢰와 협업 제안은 언제나 환영합니다.
        </p>
        {LINKS.length > 0 && (
          <div className="links">
            {LINKS.map((l) => (
              <a key={l.label} className="btn" href={l.href}>
                {l.label}
              </a>
            ))}
          </div>
        )}
        <div className="stat">
          {BADGES.map((b) => (
            <span key={b}>{b}</span>
          ))}
        </div>
      </div>
    </section>
  )
}
```

`src/components/Footer.tsx`:
```tsx
export function Footer() {
  return (
    <footer>
      © 2026 NEO_KIDO · 모든 게임은 무료로 플레이할 수 있습니다
      <div className="coin">INSERT COIN ●</div>
    </footer>
  )
}
```

`src/app/page.tsx` 전체 교체:
```tsx
import { getGames } from '@/lib/games'
import { PaletteSwap } from '@/components/PaletteSwap'
import { Hero } from '@/components/Hero'
import { Cartridge } from '@/components/Cartridge'
import { EmptySlot } from '@/components/EmptySlot'
import { Player1 } from '@/components/Player1'
import { Footer } from '@/components/Footer'

export default function Home() {
  const games = getGames()
  return (
    <>
      <PaletteSwap />
      <Hero />
      <main className="wrap">
        <section className="sec" id="games">
          <h2 className="sec-head">
            <span className="deco">►</span> SELECT GAME
          </h2>
          <p className="sec-sub">Hover a cartridge to open it — tap on mobile.</p>
          <div className="carts">
            {games.map((g, i) => (
              <Cartridge key={g.slug} game={g} index={i} />
            ))}
            <EmptySlot index={games.length} />
          </div>
        </section>
        <Player1 />
      </main>
      <Footer />
    </>
  )
}
```

- [ ] **Step 2: 빌드 및 테스트**

Run: `npm test`
Expected: PASS — 기존 테스트 전체 유지.

Run: `npm run build`
Expected: `/` 정적 생성 성공.

- [ ] **Step 3: 목업과 시각 비교 (수동)**

Run: `npm run dev` → http://localhost:3000, 그리고 `docs/superpowers/specs/2026-08-13-neo-kido-mockup.html`을 브라우저로 열어 나란히 비교:
- [ ] 히어로: NEO_KIDO 타이핑 → 언더스코어 골드 → SCROLL TO SELECT 표시
- [ ] 카트리지 4개(01–04) + EMPTY SLOT(05), 호버 시 부드럽게 확장
- [ ] SYSTEM CHECK 카트리지에만 ▶ PLAY, 나머지는 NOT INSERTED
- [ ] PALETTE SWAP → DMG 4색 전환 + 커버 재드로잉 + 새로고침 후 유지
- [ ] PLAYER 1 박스: 소개 + EMAIL 버튼 + 배지 3개
- [ ] 브라우저 폭 640px 이하: 카트리지 2행 재배치, 탭으로 열고 닫기
- [ ] 푸터 INSERT COIN ●

확인 후 dev 서버 종료. 차이가 보이면 globals.css가 아닌 컴포넌트 마크업을 목업 구조에 맞춰 수정한다(CSS는 목업에서 추출된 원본이 기준).

- [ ] **Step 4: Commit**

```powershell
git add src/app/page.tsx src/components/Player1.tsx src/components/Footer.tsx
git commit -m "feat: assemble home page with cartridge list, player 1, and footer"
```

---

### Task 8: 게임 플레이 페이지 (/play/[slug])

**Files:**
- Create: `src/app/play/[slug]/page.tsx`
- Modify: `src/app/globals.css` (플레이 셸 스타일), `src/lib/games.test.ts` (정적 파라미터 테스트 추가)

**Interfaces:**
- Consumes: `getGame`, `getGames`(Task 2)
- Produces: `/play/<slug>` 라우트 — playable 게임만 정적 생성(`dynamicParams = false`), iframe 임베드(Phase 2 외부 게임과 동일 패턴), 상단 바(◀ BACK + 게임 제목)

- [ ] **Step 1: 실패하는 테스트 작성**

`src/lib/games.test.ts`의 describe 블록 안에 추가:
```ts
  it('playable games (the future generateStaticParams source) all have real files', () => {
    const playable = getGames().filter((g) => g.playPath !== null)
    expect(playable.map((g) => g.slug)).toEqual(['system-check'])
  })
```

- [ ] **Step 2: 테스트 실행**

Run: `npm test`
Expected: PASS (레지스트리가 이미 보장하는 속성의 회귀 방어 테스트 — 새 게임에 playPath를 넣으면 이 목록에 슬러그를 추가해야 함을 알려준다). 실패한다면 content 레코드가 잘못된 것.

- [ ] **Step 3: 플레이 페이지 구현**

`src/app/play/[slug]/page.tsx`:
```tsx
import type { Metadata } from 'next'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { getGame, getGames } from '@/lib/games'

export const dynamicParams = false

export function generateStaticParams() {
  return getGames()
    .filter((g) => g.playPath !== null)
    .map((g) => ({ slug: g.slug }))
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>
}): Promise<Metadata> {
  const { slug } = await params
  const game = getGame(slug)
  return { title: game ? `${game.title} — NEO_KIDO` : 'NEO_KIDO' }
}

export default async function PlayPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const game = getGame(slug)
  if (!game || !game.playPath) notFound()

  return (
    <div className="play-shell">
      <div className="play-bar">
        <Link className="btn btn-small" href="/">
          ◀ BACK
        </Link>
        <span className="play-title">{game.title}</span>
      </div>
      <iframe
        className="play-frame"
        src={game.playPath}
        title={game.title}
        allow="fullscreen; gamepad; autoplay"
      />
    </div>
  )
}
```

`src/app/globals.css` 끝에 추가:
```css
/* play page shell */
.play-shell{position:fixed; inset:0; display:flex; flex-direction:column; background:var(--bg-deep)}
.play-bar{display:flex; align-items:center; gap:18px; padding:10px 14px;
  background:var(--bg); border-bottom:3px solid var(--frame)}
.btn-small{font-size:10px; padding:9px 12px; box-shadow:4px 4px 0 var(--shadow)}
.play-title{font-family:var(--font-display); font-size:12px; letter-spacing:1px; color:var(--text)}
.play-frame{flex:1; border:0; width:100%; background:#000}
```

- [ ] **Step 4: 빌드 및 수동 검증**

Run: `npm run build`
Expected: `/play/system-check` 정적 생성 1건 포함, 빌드 성공.

Run: `npm run dev` → http://localhost:3000 에서 SYSTEM CHECK 카트리지 열고 ▶ PLAY 클릭:
- [ ] `/play/system-check`로 이동, 상단 바(◀ BACK + SYSTEM CHECK) 아래 iframe에 진단 화면 표시
- [ ] iframe 내부 클릭 후 아무 키나 누르면 `INPUT ... OK [키]`로 바뀜 (키보드 포커스 검증)
- [ ] ◀ BACK으로 홈 복귀
- [ ] http://localhost:3000/play/starfall-drift 접속 → 404

확인 후 dev 서버 종료.

- [ ] **Step 5: Commit**

```powershell
git add src/app/play src/app/globals.css src/lib/games.test.ts
git commit -m "feat: add iframe game player page for playable cartridges"
```

---

### Task 9: README + Vercel 배포

**Files:**
- Create: `README.md`
- 배포는 사용자 계정 인증이 필요 — 아래 표시된 단계는 사용자와 함께 진행.

**Interfaces:**
- Consumes: 완성된 앱(Task 1–8)
- Produces: 게임 추가 방법이 문서화된 README, Vercel 프로덕션 배포

- [ ] **Step 1: README 작성**

`README.md`:
```markdown
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

## 테마

NIGHT(PICO-8 계열) / DMG(게임보이 4색) — 우상단 PALETTE SWAP.
선택은 localStorage(`palette`)에 저장된다. 새 UI는 두 팔레트 모두에서 확인할 것.
```

- [ ] **Step 2: 최종 검증 및 커밋**

Run: `npm test` → PASS, `npm run build` → 성공 확인 후:
```powershell
git add README.md
git commit -m "docs: add README with game registration guide"
```

- [ ] **Step 3: GitHub 리포지토리 푸시 (사용자 인증 필요)**

Run: `gh auth status`
- 인증 안 되어 있으면 사용자에게 `! gh auth login` 실행 요청.

```powershell
gh repo create neo-kido --private --source . --push
```
Expected: 리포지토리 생성 및 master 푸시 완료. (이미 원격이 있으면 `git push -u origin master`만.)

- [ ] **Step 4: Vercel 연결 (사용자 결정/인증 필요)**

두 가지 방법 중 사용자가 선택:
- **A. 대시보드**: vercel.com → Add New Project → GitHub `neo-kido` import → Framework: Next.js 자동 감지 → Deploy
- **B. CLI**: `npm i -g vercel` → `vercel login`(사용자) → `vercel --prod`

설정 변경 불필요(기본값으로 동작). 도메인 구매는 스펙 §2대로 보류 — `*.vercel.app` 사용.

- [ ] **Step 5: 프로덕션 검증**

배포 URL에서 Task 7 Step 3의 체크리스트 반복 + 추가:
- [ ] 모바일 실기기에서 카트리지 탭 열고 닫기
- [ ] `/play/system-check`에서 키 입력 반응
- [ ] 팔레트 선택이 새로고침 후 유지

---

## Self-Review 결과 (계획 검증 완료)

- **스펙 커버리지**: §3.1 팔레트/토글/저장(Task 1, 3), §3.2 폰트(Task 1), §3.3 픽셀 규칙(Task 1 CSS 추출 + Task 4 커버), §4.1 히어로(Task 5), §4.2 카트리지/빈 슬롯(Task 6, 7), §4.3 PLAYER 1/죽은 링크 금지(Task 6, 7), §4.4 푸터(Task 7), §5 인터랙션/접근성(Task 5, 6 + CSS의 hover 미디어 가드), §6 언어 정책(콘텐츠 전반), §7 Next.js/데이터 레코드/iframe(Task 1, 2, 8), §2 도메인 보류(Task 9). §8–9 범위 제외/로드맵 — 구현 없음(의도적).
- **플레이스홀더 스캔**: 통과 — 모든 코드/명령 구체화됨. 게임 3종의 `playPath: null`은 스펙 §6이 정의한 의도된 상태.
- **타입 일관성**: `Game`/`CoverScene`/`Palette`는 Task 2·3·4에서 단일 정의(scenes.ts, games.ts)를 이후 태스크가 import. `drawScene(canvas, scene, palette)` 시그니처 Task 4 정의·사용 일치. localStorage 키 `'palette'`, body 클래스 `'dmg'` 전 태스크 동일.
