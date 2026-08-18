# PIXELARIOUS 브랜드 자산 렌더러 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 개발 전용 `/brand` 라우트에서 프로필·파비콘·유튜브 배너·쇼츠 카드·포스트 템플릿 4종을 실제 캔버스로 렌더하고 지정 크기 PNG로 내보낸다.

**Architecture:** 순수 캔버스 드로잉 모듈 `src/lib/brand.ts`가 모든 자산을 그린다. React·DOM에 의존하지 않고 `BrandCanvas` 인터페이스만 받으므로 `src/lib/scenes.test.ts`의 가짜 캔버스 패턴으로 전부 단위 테스트할 수 있다. `/brand` 라우트는 `/editor`와 동일하게 개발 서버에서만 열리며, 클라이언트 컴포넌트가 폰트 로드 → 캔버스 렌더 → `toBlob` 다운로드를 담당한다. 팔레트와 폰트는 사이트와 같은 값을 쓰므로 색이 어긋날 수 없다.

**Tech Stack:** Next.js 15 (App Router), React 19, TypeScript, Canvas 2D API, Vitest + jsdom + @testing-library/react

## Global Constraints

스펙 `docs/superpowers/specs/2026-08-16-pixelarious-brand-design.md`에서 그대로 가져온다. 모든 태스크에 적용된다.

- **팔레트는 NIGHT 고정**: `deep #0C0A1C` / `bg #141127` / `surface #1D2B53` / `text #FFF1E8` / `dim #8E99D9` / `gold #FFEC27` / `accent #FF77A8` / `accent2 #29ADFF`. 이 여덟 색과 스캔라인 오버레이 외의 색을 쓰지 않는다 (스펙 §4.2)
- **폰트는 두 개뿐**: 영문·숫자 `PS2P`(Press Start 2P), 한글 `NeoDGM`(네오둥근모). 자체 호스팅 woff2가 `public/fonts/`에 이미 있다 (스펙 §4.3)
- **마크는 PIX█**: 칠흑 배경 + 흰 `PIX` + 금색 블록 커서. **테두리 프레임을 그리지 않는다.** 32px 이하에서는 글자를 빼고 커서 블록만 남긴다 (스펙 §4.1)
- **원형 크롭 안전**: 프로필 자산의 내용은 내접원 안에 들어가야 한다 (스펙 §4.1)
- **유튜브 안전 영역**: 로고·문구는 2560×1440 중앙의 1546×423 안에만 배치한다 (스펙 §5)
- **쇼츠 안전 영역**: 하단 25%는 앱 UI에 가리므로 내용을 넣지 않는다 (스펙 §8)
- **포스트에 캡션을 넣지 않는다**: 이미지 안 글자는 제목·라벨·질문만 (스펙 §6)
- **라벨은 네 종뿐**: `NEW GAME` / `DEV LOG` / `YOU ASKED` / `YOUR TURN` (스펙 §6)
- **`/brand`는 개발 서버 전용**: 배포본에서 404. `/editor`와 같은 규칙 (스펙 §7)
- **산출물 PNG를 저장소에 커밋하지 않는다** (스펙 §7)
- 픽셀 폰트 크기는 **8의 배수**로만 쓴다. Press Start 2P가 8px 설계 기준이라 그 외 크기에서 뭉갠다
- 기존 테스트 50개가 계속 통과해야 한다 (`npm test`)

---

### Task 1: 브랜드 코어 — 팔레트, 스캔라인, 마크, 프로필, 파비콘

**Files:**
- Create: `src/lib/brand.ts`
- Create: `src/lib/brand.test.ts`
- Modify: `src/lib/scenes.ts:34` (`function rng`에 `export` 추가)

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces:
  - `type BrandCanvas = { width: number; height: number; getContext(id: '2d'): CanvasRenderingContext2D | null }`
  - `const BRAND: { deep, bg, surface, text, dim, gold, accent, accent2: string }`
  - `const SCANLINE: string`
  - `const DISPLAY_FONT = 'PS2P'`, `const BODY_FONT = 'NeoDGM'`
  - `function pixelFontSize(target: number): number`
  - `function textWidth(ctx: CanvasRenderingContext2D, text: string, fontSize: number): number`
  - `function drawScanlines(ctx: CanvasRenderingContext2D, w: number, h: number, unit: number): void`
  - `function unitFor(w: number, h: number): number`
  - `function drawMarkInto(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, contentScale?: number): void`
  - `function drawMark(canvas: BrandCanvas, opts?: { letters?: boolean }): void`
  - `function drawProfile(canvas: BrandCanvas): void`
  - `function drawFavicon(canvas: BrandCanvas): void`
  - `export function rng(seed: number): () => number` (scenes.ts에서)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`src/lib/brand.test.ts` 생성:

```ts
import { describe, it, expect } from 'vitest'
import { BRAND, SCANLINE, drawMark, drawProfile, drawFavicon, pixelFontSize, type BrandCanvas } from './brand'

export function fakeCanvas(width: number, height: number) {
  const rects: { color: string; x: number; y: number; w: number; h: number }[] = []
  const texts: { color: string; text: string; x: number; y: number; font: string }[] = []
  const ctx = {
    fillStyle: '',
    font: '',
    textBaseline: '',
    imageSmoothingEnabled: true,
    fillRect(x: number, y: number, w: number, h: number) {
      rects.push({ color: String(this.fillStyle), x, y, w, h })
    },
    fillText(text: string, x: number, y: number) {
      texts.push({ color: String(this.fillStyle), text, x, y, font: String(this.font) })
    },
    drawImage() {},
  }
  return {
    canvas: { width, height, getContext: () => ctx } as unknown as BrandCanvas,
    rects,
    texts,
  }
}

const NIGHT = new Set(Object.values(BRAND))

describe('pixelFontSize', () => {
  it('snaps down to a multiple of 8 so the pixel font never blurs', () => {
    expect(pixelFontSize(100)).toBe(96)
    expect(pixelFontSize(8)).toBe(8)
    expect(pixelFontSize(3)).toBe(8)
  })
})

describe('drawMark', () => {
  it('uses only NIGHT palette colors plus the scanline overlay', () => {
    const { canvas, rects, texts } = fakeCanvas(1024, 1024)
    drawMark(canvas)
    for (const r of rects) expect(NIGHT.has(r.color) || r.color === SCANLINE, r.color).toBe(true)
    for (const t of texts) expect(NIGHT.has(t.color), t.color).toBe(true)
  })

  it('draws PIX in white with a gold cursor block and no frame', () => {
    const { canvas, rects, texts } = fakeCanvas(1024, 1024)
    drawMark(canvas)
    expect(texts.map((t) => t.text)).toEqual(['PIX'])
    expect(texts[0].color).toBe(BRAND.text)
    const gold = rects.filter((r) => r.color === BRAND.gold)
    expect(gold.length).toBe(1)
    // 프레임을 그린다면 배경보다 작은 흰 사각형이 있어야 한다 — 없어야 정상 (스펙 §4.1)
    const whiteRects = rects.filter((r) => r.color === BRAND.text)
    expect(whiteRects.length).toBe(0)
  })

  it('keeps everything inside the circle Instagram and YouTube crop to', () => {
    const { canvas, rects, texts } = fakeCanvas(1024, 1024)
    drawMark(canvas)
    const cx = 512
    const cy = 512
    const limit = 512 - 8
    const inside = (x: number, y: number) => Math.hypot(x - cx, y - cy) <= limit
    const gold = rects.filter((r) => r.color === BRAND.gold)
    expect(gold.length).toBeGreaterThan(0)
    for (const r of gold) {
      expect(inside(r.x, r.y), 'cursor top-left').toBe(true)
      expect(inside(r.x + r.w, r.y + r.h), 'cursor bottom-right').toBe(true)
    }
    for (const t of texts) {
      const size = parseInt(t.font, 10)
      expect(inside(t.x, t.y - size / 2), 'text top-left').toBe(true)
      expect(inside(t.x + t.text.length * size, t.y + size / 2), 'text bottom-right').toBe(true)
    }
  })

  it('drops the letters and draws only the cursor for the favicon size', () => {
    const { canvas, rects, texts } = fakeCanvas(32, 32)
    drawMark(canvas, { letters: false })
    expect(texts.length).toBe(0)
    expect(rects.filter((r) => r.color === BRAND.gold).length).toBe(1)
    // 32px에서 스캔라인은 노이즈가 되므로 그리지 않는다
    expect(rects.filter((r) => r.color === SCANLINE).length).toBe(0)
  })

  it('is deterministic', () => {
    const a = fakeCanvas(1024, 1024)
    const b = fakeCanvas(1024, 1024)
    drawMark(a.canvas)
    drawMark(b.canvas)
    expect(a.rects).toEqual(b.rects)
    expect(a.texts).toEqual(b.texts)
  })

  it('returns without throwing when the context is unavailable (jsdom)', () => {
    const canvas = { width: 64, height: 64, getContext: () => null } as unknown as BrandCanvas
    expect(() => drawMark(canvas)).not.toThrow()
  })
})

describe('drawProfile / drawFavicon', () => {
  it('profile keeps the letters, favicon drops them', () => {
    const p = fakeCanvas(1024, 1024)
    const f = fakeCanvas(32, 32)
    drawProfile(p.canvas)
    drawFavicon(f.canvas)
    expect(p.texts.length).toBe(1)
    expect(f.texts.length).toBe(0)
  })
})
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `npm test -- src/lib/brand.test.ts`
Expected: FAIL — `Failed to resolve import "./brand"`

- [ ] **Step 3: `scenes.ts`의 `rng`를 export한다**

`src/lib/scenes.ts`에서 34번째 줄 근처의 선언을 바꾼다:

```ts
/** mulberry32 시드 기반 PRNG — 커버가 렌더마다 같게 유지된다 */
export function rng(seed: number) {
```

(`function rng(seed: number) {` 앞에 `export `만 붙인다. 본문은 그대로 둔다.)

- [ ] **Step 4: `src/lib/brand.ts`를 만든다**

```ts
/**
 * 브랜드 자산 렌더링 — /brand 라우트에서 PNG로 내보낸다.
 *
 * 이 모듈은 DOM에 의존하지 않는다. 캔버스처럼 생긴 객체만 받으므로
 * scenes.test.ts와 같은 방식으로 전부 단위 테스트할 수 있다.
 * 팔레트와 폰트는 사이트(globals.css)와 같은 값이어야 한다 — 스펙 §4.2, §7.
 */

export type BrandCanvas = {
  width: number
  height: number
  getContext(id: '2d'): CanvasRenderingContext2D | null
}

export const BRAND = {
  deep: '#0C0A1C',
  bg: '#141127',
  surface: '#1D2B53',
  text: '#FFF1E8',
  dim: '#8E99D9',
  gold: '#FFEC27',
  accent: '#FF77A8',
  accent2: '#29ADFF',
} as const

export const SCANLINE = 'rgba(0,0,0,0.22)'

export const DISPLAY_FONT = 'PS2P'
export const BODY_FONT = 'NeoDGM'

/** Press Start 2P는 고정폭이며 전진폭이 1em이다. 브라우저에서는 measureText가 우선한다. */
const PS2P_ADVANCE = 1.0

/** PS2P는 8px 설계라 8의 배수가 아니면 뭉갠다. */
export function pixelFontSize(target: number): number {
  return Math.max(8, Math.floor(target / 8) * 8)
}

export function textWidth(
  ctx: CanvasRenderingContext2D,
  text: string,
  fontSize: number,
): number {
  const measured = typeof ctx.measureText === 'function' ? ctx.measureText(text) : null
  if (measured && typeof measured.width === 'number' && measured.width > 0) return measured.width
  return text.length * fontSize * PS2P_ADVANCE
}

/** 자산 크기에 비례하는 픽셀 단위. 1024px 자산에서 8px이 된다. */
export function unitFor(w: number, h: number): number {
  return Math.max(1, Math.round(Math.min(w, h) / 128))
}

export function drawScanlines(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
  unit: number,
): void {
  ctx.fillStyle = SCANLINE
  for (let y = 0; y < h; y += unit * 3) ctx.fillRect(0, y, w, unit)
}

export interface MarkOptions {
  /** false면 글자를 빼고 커서 블록만 그린다 (32px 이하 — 스펙 §4.1) */
  letters?: boolean
}

/**
 * 마크를 캔버스의 지정 영역에 그린다. 프로필도 배너도 워터마크도 전부 이 함수 하나를 쓴다.
 * contentScale은 내용을 영역보다 작게 잡는 비율 — 원형 크롭에는 0.707(내접 정사각형)을 넘긴다.
 */
export function drawMarkInto(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  contentScale = 1,
): void {
  ctx.fillStyle = BRAND.deep
  ctx.fillRect(x, y, w, h)
  const fontSize = pixelFontSize((Math.min(w, h) * contentScale) / 4.2)
  ctx.font = `${fontSize}px ${DISPLAY_FONT}`
  ctx.textBaseline = 'middle'
  const wordW = Math.round(textWidth(ctx, 'PIX', fontSize))
  const cursorW = Math.round(fontSize * 0.62)
  const gap = Math.round(fontSize * 0.16)
  const startX = x + Math.round((w - (wordW + gap + cursorW)) / 2)
  const midY = y + Math.round(h / 2)
  ctx.fillStyle = BRAND.text
  ctx.fillText('PIX', startX, midY)
  ctx.fillStyle = BRAND.gold
  ctx.fillRect(startX + wordW + gap, Math.round(midY - fontSize / 2), cursorW, fontSize)
}

export function drawMark(canvas: BrandCanvas, opts: MarkOptions = {}): void {
  const ctx = canvas.getContext('2d')
  if (!ctx) return
  const W = canvas.width
  const H = canvas.height

  if (opts.letters !== false) {
    // 프로필은 원형으로 잘린다. 내접 정사각형 안에서만 그린다 — 스펙 §4.1
    drawMarkInto(ctx, 0, 0, W, H, 0.707)
    drawScanlines(ctx, W, H, unitFor(W, H))
  } else {
    // 파비콘 크기에서는 스캔라인이 노이즈가 된다 — 커서 블록만 남긴다
    ctx.fillStyle = BRAND.deep
    ctx.fillRect(0, 0, W, H)
    const cursorW = Math.round(W * 0.34)
    const cursorH = Math.round(H * 0.52)
    ctx.fillStyle = BRAND.gold
    ctx.fillRect(Math.round((W - cursorW) / 2), Math.round((H - cursorH) / 2), cursorW, cursorH)
  }
}

export function drawProfile(canvas: BrandCanvas): void {
  drawMark(canvas, { letters: true })
}

export function drawFavicon(canvas: BrandCanvas): void {
  drawMark(canvas, { letters: false })
}
```

- [ ] **Step 5: 테스트를 돌려 통과하는지 확인한다**

Run: `npm test -- src/lib/brand.test.ts`
Expected: PASS — 8 tests

- [ ] **Step 6: 전체 테스트를 돌린다**

Run: `npm test`
Expected: PASS — 58 tests (기존 50 + 신규 8). `scenes.test.ts` 6개가 계속 통과해야 한다

- [ ] **Step 7: 커밋한다**

```bash
git add src/lib/brand.ts src/lib/brand.test.ts src/lib/scenes.ts
git commit -m "feat(brand): PIX 마크 렌더러 — 원형 크롭 안전, 파비콘 변형"
```

---

### Task 2: 안전 영역이 있는 자산 — 유튜브 배너와 쇼츠 카드

**Files:**
- Modify: `src/lib/brand.ts` (함수 추가)
- Modify: `src/lib/brand.test.ts` (describe 블록 추가)

**Interfaces:**
- Consumes: Task 1의 `BRAND`, `SCANLINE`, `BrandCanvas`, `pixelFontSize`, `textWidth`, `unitFor`, `drawScanlines`, `drawMarkInto`, `DISPLAY_FONT`, `BODY_FONT`; `scenes.ts`의 `rng`. **`drawMarkInto`는 Task 1에 이미 있다 — 다시 정의하지 말고 그대로 호출한다**
- Produces:
  - `const YT_SAFE: { w: 1546; h: 423 }`
  - `const SHORTS_SAFE_RATIO: 0.75`
  - `function drawYouTubeBanner(canvas: BrandCanvas): void`
  - `function drawShortsCard(canvas: BrandCanvas, headline: string[]): void`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`src/lib/brand.test.ts` 맨 아래에 붙인다 (파일 상단 import에 `drawYouTubeBanner`, `drawShortsCard`, `YT_SAFE`, `SHORTS_SAFE_RATIO`를 추가한다):

```ts
describe('drawYouTubeBanner', () => {
  it('keeps every logo and text pixel inside the safe area', () => {
    const { canvas, rects, texts } = fakeCanvas(2560, 1440)
    drawYouTubeBanner(canvas)
    const left = (2560 - YT_SAFE.w) / 2
    const top = (1440 - YT_SAFE.h) / 2
    const right = left + YT_SAFE.w
    const bottom = top + YT_SAFE.h
    // 배경·별·스캔라인은 전면을 덮어도 된다. 마크 타일(deep)과 금색 커서, 글자만 검사한다.
    for (const r of rects.filter((r) => r.color === BRAND.gold && r.w < YT_SAFE.w)) {
      expect(r.x >= left && r.x + r.w <= right, `gold x ${r.x}..${r.x + r.w}`).toBe(true)
      expect(r.y >= top && r.y + r.h <= bottom, `gold y ${r.y}..${r.y + r.h}`).toBe(true)
    }
    expect(texts.length).toBeGreaterThan(0)
    for (const t of texts) {
      const size = parseInt(t.font, 10)
      const w = t.text.length * size
      expect(t.x >= left && t.x + w <= right, `text "${t.text}" x ${t.x}..${t.x + w}`).toBe(true)
      expect(t.y - size >= top && t.y + size <= bottom, `text "${t.text}" y ${t.y}`).toBe(true)
    }
  })

  it('renders the wordmark and the bilingual tagline', () => {
    const { canvas, texts } = fakeCanvas(2560, 1440)
    drawYouTubeBanner(canvas)
    const all = texts.map((t) => t.text)
    expect(all).toContain('PIXELARIOUS')
    expect(all.some((t) => t.includes('PLAY IN YOUR BROWSER'))).toBe(true)
  })

  it('uses only NIGHT colors plus the scanline overlay', () => {
    const { canvas, rects, texts } = fakeCanvas(2560, 1440)
    drawYouTubeBanner(canvas)
    for (const r of rects) expect(NIGHT.has(r.color) || r.color === SCANLINE, r.color).toBe(true)
    for (const t of texts) expect(NIGHT.has(t.color), t.color).toBe(true)
  })

  it('is deterministic — the starfield never reshuffles between renders', () => {
    const a = fakeCanvas(2560, 1440)
    const b = fakeCanvas(2560, 1440)
    drawYouTubeBanner(a.canvas)
    drawYouTubeBanner(b.canvas)
    expect(a.rects).toEqual(b.rects)
  })
})

describe('drawShortsCard', () => {
  it('keeps content out of the bottom quarter the app UI covers', () => {
    const { canvas, rects, texts } = fakeCanvas(1080, 1920)
    drawShortsCard(canvas, ['새 게임이', '나왔습니다'])
    const floor = 1920 * SHORTS_SAFE_RATIO
    const gold = rects.filter((r) => r.color === BRAND.gold)
    expect(gold.length).toBeGreaterThan(0)
    for (const r of gold) {
      expect(r.y + r.h <= floor, `gold reaches ${r.y + r.h}`).toBe(true)
    }
    for (const t of texts) {
      const size = parseInt(t.font, 10)
      expect(t.y + size <= floor, `text "${t.text}" reaches ${t.y + size}`).toBe(true)
    }
  })

  it('renders each headline line as its own draw call', () => {
    const { canvas, texts } = fakeCanvas(1080, 1920)
    drawShortsCard(canvas, ['첫 줄', '둘째 줄'])
    const drawn = texts.map((t) => t.text)
    expect(drawn).toContain('첫 줄')
    expect(drawn).toContain('둘째 줄')
  })
})
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `npm test -- src/lib/brand.test.ts`
Expected: FAIL — `drawYouTubeBanner is not a function` (또는 import 해석 실패)

- [ ] **Step 3: `src/lib/brand.ts`에 구현을 추가한다**

파일 맨 위 import에 다음을 추가한다:

```ts
import { rng } from './scenes'
```

파일 맨 아래에 붙인다:

```ts
/** 유튜브가 모든 기기에서 보장하는 중앙 영역 — 스펙 §5 */
export const YT_SAFE = { w: 1546, h: 423 } as const

/** 쇼츠 하단 25%는 앱 UI에 가린다 — 스펙 §8 */
export const SHORTS_SAFE_RATIO = 0.75

/** 결정적 픽셀 별밭. 커버 아트와 같은 시드 계열을 쓴다. */
function drawStarfield(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
  unit: number,
  seed: number,
): void {
  const r = rng(seed)
  const count = Math.round((w * h) / 6000)
  for (let i = 0; i < count; i++) {
    const x = Math.floor(r() * w)
    const y = Math.floor(r() * h)
    // 금색은 커서 전용이다. 별에 쓰면 안전 영역 검사가 별까지 잡고,
    // 브랜드의 유일한 강조색이 배경 노이즈로 흩어진다.
    ctx.fillStyle = r() < 0.35 ? BRAND.dim : BRAND.text
    ctx.fillRect(x, y, unit * 2, unit * 2)
  }
}

export function drawYouTubeBanner(canvas: BrandCanvas): void {
  const ctx = canvas.getContext('2d')
  if (!ctx) return
  const W = canvas.width
  const H = canvas.height
  const unit = unitFor(W, H)

  ctx.fillStyle = BRAND.deep
  ctx.fillRect(0, 0, W, H)
  drawStarfield(ctx, W, H, unit, 7)

  const left = Math.round((W - YT_SAFE.w) / 2)
  const top = Math.round((H - YT_SAFE.h) / 2)

  // 마크 타일
  const tile = Math.round(YT_SAFE.h * 0.55)
  const tileY = Math.round(top + (YT_SAFE.h - tile) / 2)
  drawMarkInto(ctx, left, tileY, tile, tile)

  // 워드마크와 태그라인
  const textX = left + tile + Math.round(tile * 0.22)
  const wordSize = pixelFontSize(YT_SAFE.w * 0.055)
  ctx.font = `${wordSize}px ${DISPLAY_FONT}`
  ctx.textBaseline = 'middle'
  ctx.fillStyle = BRAND.text
  const wordY = Math.round(top + YT_SAFE.h * 0.42)
  ctx.fillText('PIXELARIOUS', textX, wordY)

  const tagSize = pixelFontSize(YT_SAFE.w * 0.022)
  ctx.font = `${tagSize}px ${BODY_FONT}`
  ctx.fillStyle = BRAND.dim
  ctx.fillText('브라우저에서 바로 플레이 · PLAY IN YOUR BROWSER', textX, Math.round(top + YT_SAFE.h * 0.72))

  drawScanlines(ctx, W, H, unit)
}

export function drawShortsCard(canvas: BrandCanvas, headline: string[]): void {
  const ctx = canvas.getContext('2d')
  if (!ctx) return
  const W = canvas.width
  const H = canvas.height
  const unit = unitFor(W, H)
  const floor = H * SHORTS_SAFE_RATIO

  ctx.fillStyle = BRAND.deep
  ctx.fillRect(0, 0, W, H)
  drawStarfield(ctx, W, H, unit, 23)

  const tile = Math.round(W * 0.26)
  drawMarkInto(ctx, Math.round((W - tile) / 2), Math.round(H * 0.14), tile, tile)

  const size = pixelFontSize(W * 0.075)
  ctx.font = `${size}px ${BODY_FONT}`
  ctx.textBaseline = 'middle'
  ctx.fillStyle = BRAND.text
  const lineGap = Math.round(size * 1.5)
  // 마지막 줄이 안전선 위에서 끝나도록 위로 쌓는다
  const lastY = Math.round(floor - size * 1.5)
  const firstY = lastY - lineGap * (headline.length - 1)
  headline.forEach((line, i) => {
    const w = textWidth(ctx, line, size)
    ctx.fillText(line, Math.round((W - w) / 2), firstY + lineGap * i)
  })

  drawScanlines(ctx, W, H, unit)
}
```

- [ ] **Step 4: 테스트를 돌려 통과하는지 확인한다**

Run: `npm test -- src/lib/brand.test.ts`
Expected: PASS — 14 tests

만약 안전 영역 테스트가 실패하면 `wordSize`/`tagSize`/`tile` 비율을 줄인다. 테스트가 실제 실패 모드(모바일에서 로고 잘림)를 잡는 것이므로 테스트를 완화하지 말고 배치를 고친다.

- [ ] **Step 5: 전체 테스트를 돌린다**

Run: `npm test`
Expected: PASS — 64 tests

- [ ] **Step 6: 커밋한다**

```bash
git add src/lib/brand.ts src/lib/brand.test.ts
git commit -m "feat(brand): 유튜브 배너·쇼츠 카드 — 안전 영역을 테스트로 강제"
```

---

### Task 3: 포스트 공용 크롬과 A 풀블리드 템플릿

**Files:**
- Modify: `src/lib/brand.ts`
- Modify: `src/lib/brand.test.ts`

**Interfaces:**
- Consumes: Task 1·2의 전부
- Produces:
  - `type PostLabel = 'NEW GAME' | 'DEV LOG' | 'YOU ASKED' | 'YOUR TURN'`
  - `const POST_LABELS: readonly PostLabel[]`
  - `interface BrandImage { width: number; height: number }`
  - `interface FullBleedPost { kind: 'full'; label: PostLabel; title: string[]; image: BrandImage | null }`
  - `type PostSpec = FullBleedPost` (Task 4·5에서 유니온이 확장된다)
  - `function drawPost(canvas: BrandCanvas, spec: PostSpec): void`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`src/lib/brand.test.ts` 맨 아래에 붙인다 (상단 import에 `drawPost`, `POST_LABELS` 추가):

```ts
describe('drawPost — A 풀블리드', () => {
  it('draws the label, the title lines and the watermark, and nothing else', () => {
    const { canvas, texts } = fakeCanvas(1080, 1080)
    drawPost(canvas, {
      kind: 'full',
      label: 'NEW GAME',
      title: ['STARFALL', 'DRIFT'],
      image: null,
    })
    const drawn = texts.map((t) => t.text)
    expect(drawn).toContain('NEW GAME')
    expect(drawn).toContain('STARFALL')
    expect(drawn).toContain('DRIFT')
    expect(drawn).toContain('PIXELARIOUS')
    // 캡션을 이미지 안에 넣지 않는다 — 스펙 §6
    expect(drawn.length).toBe(5) // 라벨 + 제목 2줄 + 워터마크 마크(PIX) + 워터마크 이름
  })

  it('paints the label badge in gold with deep text on top', () => {
    const { canvas, rects, texts } = fakeCanvas(1080, 1080)
    drawPost(canvas, { kind: 'full', label: 'DEV LOG', title: ['테스트'], image: null })
    const badge = rects.find((r) => r.color === BRAND.gold && r.w > 40 && r.h < 120)
    expect(badge).toBeDefined()
    const labelText = texts.find((t) => t.text === 'DEV LOG')
    expect(labelText?.color).toBe(BRAND.deep)
  })

  it('uses only NIGHT colors plus the scanline overlay', () => {
    const { canvas, rects, texts } = fakeCanvas(1080, 1350)
    drawPost(canvas, { kind: 'full', label: 'YOU ASKED', title: ['가'], image: null })
    for (const r of rects) expect(NIGHT.has(r.color) || r.color === SCANLINE, r.color).toBe(true)
    for (const t of texts) expect(NIGHT.has(t.color), t.color).toBe(true)
  })

  it('exposes exactly the four labels the spec allows', () => {
    expect([...POST_LABELS]).toEqual(['NEW GAME', 'DEV LOG', 'YOU ASKED', 'YOUR TURN'])
  })

  it('turns off image smoothing so screenshots stay pixel-crisp', () => {
    const rects: unknown[] = []
    let smoothing = true
    const ctx = {
      fillStyle: '',
      font: '',
      textBaseline: '',
      set imageSmoothingEnabled(v: boolean) {
        smoothing = v
      },
      get imageSmoothingEnabled() {
        return smoothing
      },
      fillRect() {
        rects.push(1)
      },
      fillText() {},
      drawImage() {},
    }
    const canvas = { width: 1080, height: 1080, getContext: () => ctx } as unknown as BrandCanvas
    drawPost(canvas, {
      kind: 'full',
      label: 'NEW GAME',
      title: ['가'],
      image: { width: 320, height: 180 },
    })
    expect(smoothing).toBe(false)
  })
})
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `npm test -- src/lib/brand.test.ts`
Expected: FAIL — `drawPost is not a function`

- [ ] **Step 3: `src/lib/brand.ts`에 구현을 추가한다**

```ts
export type PostLabel = 'NEW GAME' | 'DEV LOG' | 'YOU ASKED' | 'YOUR TURN'

/** 스펙 §6이 허용하는 라벨 전부. 새 라벨을 늘리지 않는다. */
export const POST_LABELS: readonly PostLabel[] = ['NEW GAME', 'DEV LOG', 'YOU ASKED', 'YOUR TURN']

/** drawImage에 넘길 수 있고 크기를 아는 것. 테스트에서는 크기만 있는 스텁을 쓴다. */
export interface BrandImage {
  width: number
  height: number
}

export interface FullBleedPost {
  kind: 'full'
  label: PostLabel
  title: string[]
  image: BrandImage | null
}

export type PostSpec = FullBleedPost

/** 금색 배지 + 칠흑 글자. 게시물 종류를 알리는 라벨 — 스펙 §6 */
function drawLabelBadge(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  label: PostLabel,
  fontSize: number,
): number {
  ctx.font = `${fontSize}px ${DISPLAY_FONT}`
  ctx.textBaseline = 'middle'
  const w = Math.round(textWidth(ctx, label, fontSize))
  const padX = Math.round(fontSize * 0.6)
  const padY = Math.round(fontSize * 0.5)
  const boxH = fontSize + padY * 2
  ctx.fillStyle = BRAND.gold
  ctx.fillRect(x, y, w + padX * 2, boxH)
  ctx.fillStyle = BRAND.deep
  ctx.fillText(label, x + padX, y + Math.round(boxH / 2))
  return boxH
}

/** 우하단 출처 표시. 캡처가 퍼져도 계정이 남는다 — 스펙 §6 */
function drawWatermark(ctx: CanvasRenderingContext2D, W: number, H: number): void {
  const tile = Math.round(W * 0.055)
  const pad = Math.round(W * 0.03)
  const nameSize = pixelFontSize(W * 0.016)
  ctx.font = `${nameSize}px ${DISPLAY_FONT}`
  const nameW = Math.round(textWidth(ctx, 'PIXELARIOUS', nameSize))
  const totalW = tile + Math.round(tile * 0.3) + nameW
  const x = W - pad - totalW
  const y = H - pad - tile
  drawMarkInto(ctx, x, y, tile, tile)
  ctx.font = `${nameSize}px ${DISPLAY_FONT}`
  ctx.textBaseline = 'middle'
  ctx.fillStyle = BRAND.dim
  ctx.fillText('PIXELARIOUS', x + tile + Math.round(tile * 0.3), y + Math.round(tile / 2))
}

/** 이미지를 잘라내며 캔버스를 채운다(cover). 픽셀 보간은 끈다 — 스펙 §8 */
function drawImageCover(
  ctx: CanvasRenderingContext2D,
  img: BrandImage,
  W: number,
  H: number,
): void {
  ctx.imageSmoothingEnabled = false
  const scale = Math.max(W / img.width, H / img.height)
  const dw = Math.round(img.width * scale)
  const dh = Math.round(img.height * scale)
  ctx.drawImage(
    img as unknown as CanvasImageSource,
    Math.round((W - dw) / 2),
    Math.round((H - dh) / 2),
    dw,
    dh,
  )
}

function drawFullBleed(
  ctx: CanvasRenderingContext2D,
  W: number,
  H: number,
  spec: FullBleedPost,
): void {
  if (spec.image) {
    drawImageCover(ctx, spec.image, W, H)
  } else {
    ctx.fillStyle = BRAND.bg
    ctx.fillRect(0, 0, W, H)
  }

  const pad = Math.round(W * 0.055)
  const labelSize = pixelFontSize(W * 0.022)
  const titleSize = pixelFontSize(W * 0.062)
  const lineGap = Math.round(titleSize * 1.5)

  const titleBlockH = lineGap * spec.title.length
  const badgeY = H - pad - titleBlockH - Math.round(labelSize * 2.6)
  drawLabelBadge(ctx, pad, badgeY, spec.label, labelSize)

  ctx.font = `${titleSize}px ${DISPLAY_FONT}`
  ctx.textBaseline = 'middle'
  ctx.fillStyle = BRAND.text
  const firstY = H - pad - titleBlockH + Math.round(lineGap / 2)
  spec.title.forEach((line, i) => {
    ctx.fillText(line, pad, firstY + lineGap * i)
  })

  drawWatermark(ctx, W, H)
}

export function drawPost(canvas: BrandCanvas, spec: PostSpec): void {
  const ctx = canvas.getContext('2d')
  if (!ctx) return
  const W = canvas.width
  const H = canvas.height

  if (spec.kind === 'full') drawFullBleed(ctx, W, H, spec)

  drawScanlines(ctx, W, H, unitFor(W, H))
}
```

- [ ] **Step 4: 테스트를 돌려 통과하는지 확인한다**

Run: `npm test -- src/lib/brand.test.ts`
Expected: PASS — 19 tests

- [ ] **Step 5: 전체 테스트를 돌린다**

Run: `npm test`
Expected: PASS — 69 tests

- [ ] **Step 6: 커밋한다**

```bash
git add src/lib/brand.ts src/lib/brand.test.ts
git commit -m "feat(brand): 포스트 공용 크롬(라벨 배지·워터마크) + A 풀블리드"
```

---

### Task 4: B 카트리지 템플릿

**Files:**
- Modify: `src/lib/brand.ts`
- Modify: `src/lib/brand.test.ts`

**Interfaces:**
- Consumes: Task 3의 `PostSpec`, `drawLabelBadge`, `drawWatermark`, `BrandImage`
- Produces:
  - `interface CartridgePost { kind: 'cartridge'; index: number; title: string; subtitle?: string; description: string; tags: string[]; cover: BrandImage | null }`
  - `PostSpec` 유니온에 `CartridgePost` 추가

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```ts
describe('drawPost — B 카트리지', () => {
  it('mirrors the site cartridge: slot number, title, subtitle, description, tags', () => {
    const { canvas, texts } = fakeCanvas(1080, 1080)
    drawPost(canvas, {
      kind: 'cartridge',
      index: 0,
      title: 'STARFALL DRIFT',
      subtitle: '스타폴 드리프트',
      description: '탭 한 번으로 궤도를 바꿔 별에서 별로.',
      tags: ['GODOT 4', 'ARCADE'],
      cover: null,
    })
    const drawn = texts.map((t) => t.text)
    expect(drawn).toContain('01')
    expect(drawn).toContain('STARFALL DRIFT')
    expect(drawn).toContain('스타폴 드리프트')
    expect(drawn).toContain('탭 한 번으로 궤도를 바꿔 별에서 별로.')
    expect(drawn).toContain('GODOT 4')
    expect(drawn).toContain('ARCADE')
  })

  it('zero-pads the slot number the way the site does', () => {
    const { canvas, texts } = fakeCanvas(1080, 1080)
    drawPost(canvas, {
      kind: 'cartridge',
      index: 11,
      title: 'X',
      description: 'y',
      tags: [],
      cover: null,
    })
    expect(texts.map((t) => t.text)).toContain('12')
  })

  it('omits the subtitle line when there is none', () => {
    const { canvas, texts } = fakeCanvas(1080, 1080)
    drawPost(canvas, {
      kind: 'cartridge',
      index: 0,
      title: 'PIXEL PONG.EXE',
      description: '하루 만에 만든 퐁 변형.',
      tags: [],
      cover: null,
    })
    const drawn = texts.map((t) => t.text)
    expect(drawn).toContain('PIXEL PONG.EXE')
    expect(drawn.filter((t) => t === '')).toHaveLength(0)
  })

  it('draws the cartridge box on the surface color with a NEW GAME badge', () => {
    const { canvas, rects, texts } = fakeCanvas(1080, 1080)
    drawPost(canvas, {
      kind: 'cartridge',
      index: 0,
      title: 'A',
      description: 'b',
      tags: [],
      cover: null,
    })
    expect(rects.some((r) => r.color === BRAND.surface)).toBe(true)
    expect(texts.map((t) => t.text)).toContain('NEW GAME')
  })

  it('uses only NIGHT colors plus the scanline overlay', () => {
    const { canvas, rects, texts } = fakeCanvas(1080, 1350)
    drawPost(canvas, {
      kind: 'cartridge',
      index: 2,
      title: 'A',
      subtitle: '가',
      description: 'b',
      tags: ['T'],
      cover: null,
    })
    for (const r of rects) expect(NIGHT.has(r.color) || r.color === SCANLINE, r.color).toBe(true)
    for (const t of texts) expect(NIGHT.has(t.color), t.color).toBe(true)
  })
})
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `npm test -- src/lib/brand.test.ts`
Expected: FAIL — 카트리지 타입이 `PostSpec`에 없어 타입 에러, 또는 `01`을 찾지 못함

- [ ] **Step 3: `src/lib/brand.ts`에 구현을 추가한다**

`PostSpec` 정의를 바꾼다:

```ts
export type PostSpec = FullBleedPost | CartridgePost
```

인터페이스와 드로잉을 추가한다:

```ts
export interface CartridgePost {
  kind: 'cartridge'
  /** 0부터 세는 슬롯 인덱스. 화면에는 1부터 두 자리로 표시한다(사이트와 동일). */
  index: number
  title: string
  subtitle?: string
  description: string
  tags: string[]
  /** 미리 렌더한 커버(100×42 캔버스). 없으면 자리를 비운다. */
  cover: BrandImage | null
}

function drawCartridge(
  ctx: CanvasRenderingContext2D,
  W: number,
  H: number,
  spec: CartridgePost,
): void {
  ctx.fillStyle = BRAND.deep
  ctx.fillRect(0, 0, W, H)

  const pad = Math.round(W * 0.07)
  const boxW = W - pad * 2
  const boxX = pad
  const border = Math.max(2, Math.round(W * 0.005))

  const noSize = pixelFontSize(W * 0.02)
  const titleSize = pixelFontSize(W * 0.036)
  const subSize = pixelFontSize(W * 0.024)
  const descSize = pixelFontSize(W * 0.026)
  const tagSize = pixelFontSize(W * 0.016)

  const coverW = Math.round(boxW * 0.42)
  const coverH = Math.round((coverW * 42) / 100)
  const stripH = coverH + Math.round(W * 0.06)
  const footH = Math.round(descSize * 2.4 + (spec.tags.length ? tagSize * 3 : 0))
  const boxH = stripH + footH
  const boxY = Math.round((H - boxH) / 2)

  // 흰 프레임 위에 서피스 색 본체 — 사이트 .cart와 같은 구성
  ctx.fillStyle = BRAND.text
  ctx.fillRect(boxX - border, boxY - border, boxW + border * 2, boxH + border * 2)
  ctx.fillStyle = BRAND.surface
  ctx.fillRect(boxX, boxY, boxW, boxH)

  // 슬롯 번호
  const innerPad = Math.round(W * 0.028)
  ctx.font = `${noSize}px ${DISPLAY_FONT}`
  ctx.textBaseline = 'middle'
  ctx.fillStyle = BRAND.dim
  const noText = String(spec.index + 1).padStart(2, '0')
  ctx.fillText(noText, boxX + innerPad, boxY + Math.round(stripH / 2))

  // 커버
  const coverX = boxX + innerPad + Math.round(noSize * 2.6)
  const coverY = boxY + Math.round((stripH - coverH) / 2)
  ctx.fillStyle = BRAND.text
  ctx.fillRect(coverX - border, coverY - border, coverW + border * 2, coverH + border * 2)
  if (spec.cover) {
    ctx.imageSmoothingEnabled = false
    ctx.drawImage(spec.cover as unknown as CanvasImageSource, coverX, coverY, coverW, coverH)
  } else {
    ctx.fillStyle = BRAND.bg
    ctx.fillRect(coverX, coverY, coverW, coverH)
  }

  // 제목 / 부제
  const textX = coverX + coverW + innerPad
  const hasSub = typeof spec.subtitle === 'string' && spec.subtitle.length > 0
  const titleY = boxY + Math.round(stripH / 2) - (hasSub ? Math.round(subSize * 0.9) : 0)
  ctx.font = `${titleSize}px ${DISPLAY_FONT}`
  ctx.fillStyle = BRAND.text
  ctx.fillText(spec.title, textX, titleY)
  if (hasSub) {
    ctx.font = `${subSize}px ${BODY_FONT}`
    ctx.fillStyle = BRAND.dim
    ctx.fillText(spec.subtitle as string, textX, titleY + Math.round(subSize * 1.8))
  }

  // 점선 구분선 아래 설명 + 태그
  const footY = boxY + stripH
  ctx.fillStyle = BRAND.dim
  for (let x = boxX + innerPad; x < boxX + boxW - innerPad; x += border * 6) {
    ctx.fillRect(x, footY, border * 3, border)
  }
  ctx.font = `${descSize}px ${BODY_FONT}`
  ctx.fillStyle = BRAND.text
  ctx.fillText(spec.description, boxX + innerPad, footY + Math.round(descSize * 1.4))

  if (spec.tags.length) {
    ctx.font = `${tagSize}px ${DISPLAY_FONT}`
    ctx.fillStyle = BRAND.accent2
    let tx = boxX + innerPad
    const ty = footY + Math.round(descSize * 1.4) + Math.round(tagSize * 2.6)
    for (const tag of spec.tags) {
      ctx.fillText(tag, tx, ty)
      tx += Math.round(textWidth(ctx, tag, tagSize)) + Math.round(tagSize * 1.6)
    }
  }

  // 출시 공지 전용 템플릿이므로 라벨은 항상 NEW GAME이다
  drawLabelBadge(ctx, boxX, Math.round(boxY - pad * 0.9), 'NEW GAME', pixelFontSize(W * 0.022))
  drawWatermark(ctx, W, H)
}
```

`drawPost`의 분기를 바꾼다:

```ts
export function drawPost(canvas: BrandCanvas, spec: PostSpec): void {
  const ctx = canvas.getContext('2d')
  if (!ctx) return
  const W = canvas.width
  const H = canvas.height

  if (spec.kind === 'full') drawFullBleed(ctx, W, H, spec)
  else if (spec.kind === 'cartridge') drawCartridge(ctx, W, H, spec)

  drawScanlines(ctx, W, H, unitFor(W, H))
}
```

- [ ] **Step 4: 테스트를 돌려 통과하는지 확인한다**

Run: `npm test -- src/lib/brand.test.ts`
Expected: PASS — 24 tests

- [ ] **Step 5: 전체 테스트를 돌린다**

Run: `npm test`
Expected: PASS — 74 tests

- [ ] **Step 6: 커밋한다**

```bash
git add src/lib/brand.ts src/lib/brand.test.ts
git commit -m "feat(brand): B 카트리지 템플릿 — 사이트 배너 구조를 그대로 재현"
```

---

### Task 5: C 터미널 로그와 D 질문 카드 템플릿

**Files:**
- Modify: `src/lib/brand.ts`
- Modify: `src/lib/brand.test.ts`

**Interfaces:**
- Consumes: Task 3·4의 전부
- Produces:
  - `interface TerminalLine { text: string; status?: string; tone?: 'ok' | 'gold' }`
  - `interface TerminalPost { kind: 'terminal'; label: PostLabel; log: TerminalLine[]; headline: string[] }`
  - `interface QuestionPost { kind: 'question'; label: PostLabel; question: string[] }`
  - `PostSpec` 유니온 확장

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```ts
describe('drawPost — C 터미널 로그', () => {
  it('draws each log line with its status and the headline lines', () => {
    const { canvas, texts } = fakeCanvas(1080, 1080)
    drawPost(canvas, {
      kind: 'terminal',
      label: 'DEV LOG',
      log: [
        { text: '> BUILD v0.3.1', status: '... OK', tone: 'ok' },
        { text: '> LAMP RADIUS 8 -> 5', status: '... CHANGED', tone: 'gold' },
      ],
      headline: ['동굴이 훨씬', '무서워졌습니다'],
    })
    const drawn = texts.map((t) => t.text)
    expect(drawn).toContain('> BUILD v0.3.1')
    expect(drawn).toContain('... OK')
    expect(drawn).toContain('... CHANGED')
    expect(drawn).toContain('동굴이 훨씬')
    expect(drawn).toContain('무서워졌습니다')
    expect(drawn).toContain('DEV LOG')
  })

  it('colors ok status blue and gold status gold', () => {
    const { canvas, texts } = fakeCanvas(1080, 1080)
    drawPost(canvas, {
      kind: 'terminal',
      label: 'DEV LOG',
      log: [
        { text: '> A', status: '... OK', tone: 'ok' },
        { text: '> B', status: '... CHANGED', tone: 'gold' },
      ],
      headline: ['가'],
    })
    expect(texts.find((t) => t.text === '... OK')?.color).toBe(BRAND.accent2)
    expect(texts.find((t) => t.text === '... CHANGED')?.color).toBe(BRAND.gold)
  })

  it('draws a gold cursor block after the headline', () => {
    const { canvas, rects } = fakeCanvas(1080, 1080)
    drawPost(canvas, {
      kind: 'terminal',
      label: 'DEV LOG',
      log: [],
      headline: ['가'],
    })
    // 라벨 배지 + 워터마크 커서 + 헤드라인 커서 = 금색 사각형 3개 이상
    expect(rects.filter((r) => r.color === BRAND.gold).length).toBeGreaterThanOrEqual(3)
  })

  it('handles an empty log without throwing', () => {
    const { canvas, texts } = fakeCanvas(1080, 1080)
    expect(() =>
      drawPost(canvas, { kind: 'terminal', label: 'DEV LOG', log: [], headline: ['가'] }),
    ).not.toThrow()
    expect(texts.map((t) => t.text)).toContain('가')
  })
})

describe('drawPost — D 질문 카드', () => {
  it('draws the label and every question line', () => {
    const { canvas, texts } = fakeCanvas(1080, 1350)
    drawPost(canvas, {
      kind: 'question',
      label: 'YOUR TURN',
      question: ['다음 게임,', '어떤 걸', '보고 싶으세요?'],
    })
    const drawn = texts.map((t) => t.text)
    expect(drawn).toContain('YOUR TURN')
    expect(drawn).toContain('다음 게임,')
    expect(drawn).toContain('어떤 걸')
    expect(drawn).toContain('보고 싶으세요?')
  })

  it('uses only NIGHT colors plus the scanline overlay', () => {
    const { canvas, rects, texts } = fakeCanvas(1080, 1080)
    drawPost(canvas, { kind: 'question', label: 'YOUR TURN', question: ['가?'] })
    for (const r of rects) expect(NIGHT.has(r.color) || r.color === SCANLINE, r.color).toBe(true)
    for (const t of texts) expect(NIGHT.has(t.color), t.color).toBe(true)
  })
})
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `npm test -- src/lib/brand.test.ts`
Expected: FAIL — `terminal` / `question` kind가 `PostSpec`에 없음

- [ ] **Step 3: `src/lib/brand.ts`에 구현을 추가한다**

```ts
export interface TerminalLine {
  text: string
  status?: string
  tone?: 'ok' | 'gold'
}

export interface TerminalPost {
  kind: 'terminal'
  label: PostLabel
  log: TerminalLine[]
  headline: string[]
}

export interface QuestionPost {
  kind: 'question'
  label: PostLabel
  question: string[]
}

export type PostSpec = FullBleedPost | CartridgePost | TerminalPost | QuestionPost

function drawTerminal(
  ctx: CanvasRenderingContext2D,
  W: number,
  H: number,
  spec: TerminalPost,
): void {
  ctx.fillStyle = BRAND.deep
  ctx.fillRect(0, 0, W, H)

  const pad = Math.round(W * 0.075)
  const labelSize = pixelFontSize(W * 0.022)
  drawLabelBadge(ctx, pad, pad, spec.label, labelSize)

  const logSize = pixelFontSize(W * 0.022)
  const logGap = Math.round(logSize * 2.4)
  let y = pad + Math.round(labelSize * 4.2)

  ctx.textBaseline = 'middle'
  for (const line of spec.log) {
    ctx.font = `${logSize}px ${DISPLAY_FONT}`
    ctx.fillStyle = BRAND.dim
    ctx.fillText(line.text, pad, y)
    if (line.status) {
      const x = pad + Math.round(textWidth(ctx, line.text, logSize))
      ctx.fillStyle = line.tone === 'gold' ? BRAND.gold : BRAND.accent2
      ctx.fillText(line.status, x, y)
    }
    y += logGap
  }

  const headSize = pixelFontSize(W * 0.062)
  const headGap = Math.round(headSize * 1.5)
  y += Math.round(headSize * 0.8)
  ctx.font = `${headSize}px ${BODY_FONT}`
  ctx.fillStyle = BRAND.text
  let lastX = pad
  spec.headline.forEach((line, i) => {
    const lineY = y + headGap * i
    ctx.fillText(line, pad, lineY)
    lastX = pad + Math.round(textWidth(ctx, line, headSize))
  })

  // 마지막 줄 끝에서 커서가 깜빡인다 — 정지 이미지에서는 켜진 상태 (스펙 §4.1)
  const lastY = y + headGap * Math.max(0, spec.headline.length - 1)
  ctx.fillStyle = BRAND.gold
  ctx.fillRect(
    lastX + Math.round(headSize * 0.16),
    Math.round(lastY - headSize / 2),
    Math.round(headSize * 0.62),
    headSize,
  )

  drawWatermark(ctx, W, H)
}

function drawQuestion(
  ctx: CanvasRenderingContext2D,
  W: number,
  H: number,
  spec: QuestionPost,
): void {
  ctx.fillStyle = BRAND.deep
  ctx.fillRect(0, 0, W, H)

  const pad = Math.round(W * 0.075)
  const labelSize = pixelFontSize(W * 0.022)
  drawLabelBadge(ctx, pad, pad, spec.label, labelSize)

  // 배경을 비워 피드에서 눈에 걸리게 한다 — 글자는 크게, 가운데 정렬하지 않고 왼쪽에 쌓는다
  const qSize = pixelFontSize(W * 0.085)
  const qGap = Math.round(qSize * 1.45)
  const blockH = qGap * spec.question.length
  const firstY = Math.round((H - blockH) / 2 + qGap / 2)

  ctx.font = `${qSize}px ${BODY_FONT}`
  ctx.textBaseline = 'middle'
  ctx.fillStyle = BRAND.text
  spec.question.forEach((line, i) => {
    ctx.fillText(line, pad, firstY + qGap * i)
  })

  drawWatermark(ctx, W, H)
}
```

`drawPost`의 분기를 바꾼다:

```ts
export function drawPost(canvas: BrandCanvas, spec: PostSpec): void {
  const ctx = canvas.getContext('2d')
  if (!ctx) return
  const W = canvas.width
  const H = canvas.height

  if (spec.kind === 'full') drawFullBleed(ctx, W, H, spec)
  else if (spec.kind === 'cartridge') drawCartridge(ctx, W, H, spec)
  else if (spec.kind === 'terminal') drawTerminal(ctx, W, H, spec)
  else drawQuestion(ctx, W, H, spec)

  drawScanlines(ctx, W, H, unitFor(W, H))
}
```

- [ ] **Step 4: 테스트를 돌려 통과하는지 확인한다**

Run: `npm test -- src/lib/brand.test.ts`
Expected: PASS — 30 tests

- [ ] **Step 5: 전체 테스트를 돌린다**

Run: `npm test`
Expected: PASS — 80 tests

- [ ] **Step 6: 커밋한다**

```bash
git add src/lib/brand.ts src/lib/brand.test.ts
git commit -m "feat(brand): C 터미널 로그·D 질문 카드 템플릿"
```

---

### Task 6: `/brand` 라우트와 PNG 내보내기 UI

**Files:**
- Create: `src/app/brand/page.tsx`
- Create: `src/app/brand/page.test.tsx`
- Create: `src/components/BrandClient.tsx`
- Create: `src/components/BrandClient.module.css`
- Create: `src/components/BrandClient.test.tsx`

**Interfaces:**
- Consumes: Task 1~5의 `drawProfile`, `drawFavicon`, `drawYouTubeBanner`, `drawShortsCard`, `drawPost`, `PostSpec`, `POST_LABELS`; `@/lib/games`의 `getGames`, `Game`
- Produces: 브라우저에서 쓰는 도구. 다른 태스크가 의존하지 않는다

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`src/app/brand/page.test.tsx` 생성:

```ts
import { describe, it, expect, vi } from 'vitest'

vi.mock('next/navigation', () => ({
  notFound: () => {
    throw new Error('NEXT_NOT_FOUND')
  },
}))

vi.mock('@/lib/games', () => ({ getGames: () => [] }))

describe('/brand page', () => {
  it('404s outside development so the tool never ships (NODE_ENV=test here)', async () => {
    const { default: BrandPage } = await import('./page')
    expect(() => BrandPage()).toThrow('NEXT_NOT_FOUND')
  })
})
```

`src/components/BrandClient.test.tsx` 생성:

```ts
import { describe, it, expect, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { BrandClient } from './BrandClient'
import type { Game } from '@/lib/games'

afterEach(cleanup)

const games: Game[] = [
  {
    slug: 'starfall-drift',
    order: 10,
    title: 'STARFALL DRIFT',
    description: '탭 한 번으로 궤도를 바꿔 별에서 별로.',
    tags: ['GODOT 4', 'ARCADE'],
    coverScene: 'starfall',
    playPath: null,
  },
]

describe('BrandClient', () => {
  it('renders one canvas per asset at its exact export size', () => {
    const { container } = render(<BrandClient games={games} />)
    const profile = container.querySelector('canvas[data-asset="profile"]')
    expect(profile?.getAttribute('width')).toBe('1024')
    expect(profile?.getAttribute('height')).toBe('1024')
    const banner = container.querySelector('canvas[data-asset="youtube-banner"]')
    expect(banner?.getAttribute('width')).toBe('2560')
    expect(banner?.getAttribute('height')).toBe('1440')
    const favicon = container.querySelector('canvas[data-asset="favicon"]')
    expect(favicon?.getAttribute('width')).toBe('32')
  })

  it('offers a PNG download for every asset', () => {
    const { container } = render(<BrandClient games={games} />)
    const canvases = container.querySelectorAll('canvas[data-asset]')
    const buttons = screen.getAllByRole('button', { name: /PNG 내보내기/ })
    expect(buttons.length).toBe(canvases.length)
  })

  it('lists the four post templates and no others', () => {
    render(<BrandClient games={games} />)
    expect(screen.getByText('A. 풀블리드')).toBeDefined()
    expect(screen.getByText('B. 카트리지')).toBeDefined()
    expect(screen.getByText('C. 터미널 로그')).toBeDefined()
    expect(screen.getByText('D. 질문 카드')).toBeDefined()
  })

  it('survives jsdom where getContext returns null', () => {
    expect(() => render(<BrandClient games={games} />)).not.toThrow()
  })
})
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `npm test -- src/app/brand src/components/BrandClient.test.tsx`
Expected: FAIL — `Failed to resolve import "./page"` 및 `"./BrandClient"`

- [ ] **Step 3: 페이지를 만든다**

`src/app/brand/page.tsx`:

```tsx
import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { getGames } from '@/lib/games'
import { BrandClient } from '@/components/BrandClient'

export const metadata: Metadata = { title: 'BRAND ASSETS — PIXELARIOUS' }

export default function BrandPage() {
  // 브랜드 자산 제작 도구다. 배포된 사이트에는 존재하지 않는다 (스펙 §7).
  if (process.env.NODE_ENV !== 'development') notFound()

  return <BrandClient games={getGames()} />
}
```

- [ ] **Step 4: 클라이언트 컴포넌트를 만든다**

`src/components/BrandClient.module.css`:

```css
.wrap { max-width: 1100px; margin: 0 auto; padding: 32px 20px 80px; }
.head { font-family: var(--font-display); font-size: 18px; margin: 0 0 6px; }
.sub { color: var(--dim); margin: 0 0 28px; font-size: 15px; }
.group { margin-bottom: 44px; }
.groupHead { font-family: var(--font-display); font-size: 13px; color: var(--gold); margin: 0 0 14px; }
.item { border: 3px solid var(--frame); background: var(--surface); padding: 14px; margin-bottom: 18px; }
.itemHead { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 12px; }
.name { font-family: var(--font-display); font-size: 11px; }
.size { color: var(--dim); font-size: 13px; }
.preview { background: var(--bg-deep); display: flex; justify-content: center; padding: 12px; overflow: hidden; }
.preview canvas { image-rendering: pixelated; max-width: 100%; height: auto; }
.btn {
  font-family: var(--font-display); font-size: 10px; cursor: pointer;
  background: var(--btn-bg); color: var(--btn-text);
  border: 3px solid var(--frame); box-shadow: 4px 4px 0 var(--shadow); padding: 8px 12px;
}
.btn:active { transform: translate(2px, 2px); box-shadow: 2px 2px 0 var(--shadow); }
.field { display: flex; flex-direction: column; gap: 5px; margin-bottom: 10px; }
.field label { font-size: 13px; color: var(--dim); }
.field input, .field textarea {
  font-family: var(--font-body); font-size: 15px; padding: 7px 9px;
  background: var(--bg-deep); color: var(--text); border: 2px solid var(--dim);
}
```

`src/components/BrandClient.tsx`:

```tsx
'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  drawProfile,
  drawFavicon,
  drawYouTubeBanner,
  drawShortsCard,
  drawPost,
  type PostSpec,
} from '@/lib/brand'
import { drawScene } from '@/lib/scenes'
import type { Game } from '@/lib/games'
import styles from './BrandClient.module.css'

interface AssetDef {
  id: string
  name: string
  w: number
  h: number
  draw: (canvas: HTMLCanvasElement) => void
}

/** 미리보기 표시 폭. 내보내기는 항상 원본 크기다. */
const PREVIEW_MAX = 320

/** 훅이 아니다 — useMemo로 감싸 렌더마다 자산이 새로 만들어지지 않게 한다. */
function buildAssets(games: Game[]): AssetDef[] {
  const first = games[0]

  /** 카트리지 커버를 사이트와 같은 100×42로 미리 그려 넘긴다. */
  const renderCover = (): HTMLCanvasElement | null => {
    if (typeof document === 'undefined' || !first) return null
    const c = document.createElement('canvas')
    c.width = 100
    c.height = 42
    if (!c.getContext('2d')) return null
    drawScene(c, first.coverScene, 'night')
    return c
  }

  const samplePosts: { id: string; name: string; w: number; h: number; spec: PostSpec }[] = [
    {
      id: 'post-full',
      name: 'A. 풀블리드',
      w: 1080,
      h: 1080,
      spec: {
        kind: 'full',
        label: 'NEW GAME',
        title: first ? first.title.split(' ') : ['NEW', 'GAME'],
        image: null,
      },
    },
    {
      id: 'post-cartridge',
      name: 'B. 카트리지',
      w: 1080,
      h: 1080,
      spec: {
        kind: 'cartridge',
        index: 0,
        title: first?.title ?? 'TITLE',
        subtitle: first?.subtitle,
        description: first?.description.split('\n')[0] ?? '',
        tags: first?.tags ?? [],
        cover: null,
      },
    },
    {
      id: 'post-terminal',
      name: 'C. 터미널 로그',
      w: 1080,
      h: 1080,
      spec: {
        kind: 'terminal',
        label: 'DEV LOG',
        log: [
          { text: '> BUILD v0.3.1', status: ' ... OK', tone: 'ok' },
          { text: '> LAMP RADIUS 8 -> 5', status: ' ... CHANGED', tone: 'gold' },
        ],
        headline: ['동굴이 훨씬', '무서워졌습니다'],
      },
    },
    {
      id: 'post-question',
      name: 'D. 질문 카드',
      w: 1080,
      h: 1350,
      spec: {
        kind: 'question',
        label: 'YOUR TURN',
        question: ['다음 게임,', '어떤 걸', '보고 싶으세요?'],
      },
    },
  ]

  return [
    { id: 'profile', name: '프로필 (3채널 공통)', w: 1024, h: 1024, draw: (c) => drawProfile(c) },
    { id: 'favicon', name: '파비콘', w: 32, h: 32, draw: (c) => drawFavicon(c) },
    {
      id: 'youtube-banner',
      name: '유튜브 배너',
      w: 2560,
      h: 1440,
      draw: (c) => drawYouTubeBanner(c),
    },
    {
      id: 'shorts-card',
      name: '쇼츠 카드',
      w: 1080,
      h: 1920,
      draw: (c) => drawShortsCard(c, ['새 게임이', '나왔습니다']),
    },
    ...samplePosts.map((p) => ({
      id: p.id,
      name: p.name,
      w: p.w,
      h: p.h,
      draw: (c: HTMLCanvasElement) => {
        const spec =
          p.spec.kind === 'cartridge' ? { ...p.spec, cover: renderCover() } : p.spec
        drawPost(c, spec)
      },
    })),
  ]
}

function AssetCard({ asset }: { asset: AssetDef }) {
  const ref = useRef<HTMLCanvasElement>(null)
  const [ready, setReady] = useState(false)

  useEffect(() => {
    let cancelled = false
    const paint = () => {
      if (cancelled || !ref.current) return
      asset.draw(ref.current)
      setReady(true)
    }
    // 픽셀 폰트가 로드되기 전에 그리면 대체 폰트로 렌더된다
    const fonts = (document as Document & { fonts?: FontFaceSet }).fonts
    if (fonts?.load) {
      Promise.all([fonts.load('16px PS2P'), fonts.load('16px NeoDGM')]).then(paint, paint)
    } else {
      paint()
    }
    return () => {
      cancelled = true
    }
  }, [asset])

  const download = useCallback(() => {
    const canvas = ref.current
    if (!canvas || typeof canvas.toBlob !== 'function') return
    canvas.toBlob((blob) => {
      if (!blob) return
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `pixelarious-${asset.id}-${asset.w}x${asset.h}.png`
      a.click()
      URL.revokeObjectURL(url)
    }, 'image/png')
  }, [asset])

  const scale = Math.min(1, PREVIEW_MAX / asset.w)

  return (
    <div className={styles.item}>
      <div className={styles.itemHead}>
        <span className={styles.name}>{asset.name}</span>
        <span className={styles.size}>
          {asset.w} × {asset.h}
        </span>
        <button type="button" className={styles.btn} onClick={download} disabled={!ready}>
          PNG 내보내기
        </button>
      </div>
      <div className={styles.preview}>
        <canvas
          ref={ref}
          data-asset={asset.id}
          width={asset.w}
          height={asset.h}
          style={{ width: `${Math.round(asset.w * scale)}px` }}
        />
      </div>
    </div>
  )
}

export function BrandClient({ games }: { games: Game[] }) {
  const assets = useMemo(() => buildAssets(games), [games])
  return (
    <main className={styles.wrap}>
      <h1 className={styles.head}>BRAND ASSETS</h1>
      <p className={styles.sub}>
        스펙 <code>2026-08-16-pixelarious-brand-design.md</code> 기준으로 렌더합니다. 내보낸 PNG는
        저장소에 커밋하지 않습니다.
      </p>
      <div className={styles.group}>
        <h2 className={styles.groupHead}>▍ 계정 자산</h2>
        {assets.slice(0, 4).map((a) => (
          <AssetCard key={a.id} asset={a} />
        ))}
      </div>
      <div className={styles.group}>
        <h2 className={styles.groupHead}>▍ 포스트 템플릿</h2>
        {assets.slice(4).map((a) => (
          <AssetCard key={a.id} asset={a} />
        ))}
      </div>
    </main>
  )
}
```

- [ ] **Step 5: 테스트를 돌려 통과하는지 확인한다**

Run: `npm test -- src/app/brand src/components/BrandClient.test.tsx`
Expected: PASS — 5 tests

- [ ] **Step 6: 전체 테스트를 돌린다**

Run: `npm test`
Expected: PASS — 85 tests

- [ ] **Step 7: 실제 브라우저에서 확인한다**

Run: `npm run dev`
`http://localhost:3000/brand` 를 연다. 확인할 것:
- 자산 8개가 모두 그려진다 (프로필·파비콘·유튜브 배너·쇼츠 카드·포스트 4종)
- `PIX` 글자가 Press Start 2P로 나온다 (대체 폰트가 아니다 — 획이 각져야 한다)
- 한글이 두부(□)로 깨지지 않는다
- 프로필의 `PIX█`가 상하좌우 여백 안에 들어간다
- 유튜브 배너의 로고·문구가 중앙에 몰려 있다
- "PNG 내보내기"를 누르면 `pixelarious-profile-1024x1024.png` 같은 이름으로 받아진다

`npm run build`로 프로덕션 빌드가 통과하는지도 확인한다.

- [ ] **Step 8: 커밋한다**

```bash
git add src/app/brand src/components/BrandClient.tsx src/components/BrandClient.module.css src/components/BrandClient.test.tsx
git commit -m "feat(brand): dev 전용 /brand 라우트 — 자산 렌더링과 PNG 내보내기"
```

---

### Task 7: 배포 안전성 검증과 문서화

**Files:**
- Modify: `README.md`
- Create: `src/app/brand/production.test.ts`

**Interfaces:**
- Consumes: Task 6의 `/brand` 라우트
- Produces: 없음 (마무리 태스크)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`src/app/brand/production.test.ts` 생성 — `/editor`와 `/api/editor`가 프로덕션에서 닫혀 있듯 `/brand`도 닫혀 있어야 한다. 소스를 읽어 게이트가 존재하는지 검사한다:

```ts
import { describe, it, expect } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'

const PAGE = path.join(process.cwd(), 'src', 'app', 'brand', 'page.tsx')

describe('/brand production gate', () => {
  it('keeps the NODE_ENV guard that the deployed site relies on', () => {
    const src = fs.readFileSync(PAGE, 'utf8')
    expect(src).toContain("process.env.NODE_ENV !== 'development'")
    expect(src).toContain('notFound()')
  })

  it('never imports node:fs — the brand renderer must stay client-safe', () => {
    const client = fs.readFileSync(
      path.join(process.cwd(), 'src', 'lib', 'brand.ts'),
      'utf8',
    )
    expect(client).not.toContain('node:fs')
    expect(client).not.toContain('node:path')
  })
})
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `npm test -- src/app/brand/production.test.ts`
Expected: PASS (Task 6에서 이미 게이트를 넣었으므로 바로 통과한다). 만약 FAIL이면 `page.tsx`에 가드가 빠진 것이므로 Task 6 Step 3의 코드를 다시 확인한다

- [ ] **Step 3: README에 사용법을 추가한다**

`README.md`의 "## 테마" 섹션 **앞에** 다음을 삽입한다:

```markdown
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
```

- [ ] **Step 4: 전체 테스트와 빌드를 돌린다**

Run: `npm test`
Expected: PASS — 87 tests

Run: `npm run build`
Expected: 빌드 성공. 출력의 라우트 목록에 `/brand`가 나오더라도 런타임 가드가 404를 반환한다

- [ ] **Step 5: 프로덕션 동작을 실제로 확인한다**

```bash
npm run build && npm start
```

`http://localhost:3000/brand` 를 연다.
Expected: 404 페이지. (`/editor`도 마찬가지로 404여야 한다.)
확인 후 `Ctrl+C`로 종료한다.

- [ ] **Step 6: 커밋한다**

```bash
git add README.md src/app/brand/production.test.ts
git commit -m "docs(brand): /brand 사용법 문서화 + 프로덕션 게이트 회귀 테스트"
```

---

## 코드 작업이 아닌 스펙 항목

스펙에는 있지만 이 플랜에 태스크가 없는 것들이다. 빠뜨린 게 아니라 코드가 필요 없어서다.

- **소개글 입력 (스펙 §5)** — 세 채널 프로필 소개글은 사용자가 각 앱에서 직접 붙여넣는다. 문안은 스펙 §5에 확정되어 있다
- **사이트 피드백 창구 (스펙 §9)** — 외부 폼 링크는 **기존 `/editor`의 PLAYER 1 탭에서 링크를 추가하면 끝난다.** `content/profile.json`의 `links` 배열이 이미 이름·주소 쌍을 지원하고, 둘 다 채운 링크만 화면에 나온다. 코드 변경이 필요 없다
- **화자·톤·게시 리듬 (스펙 §3, §11)** — 운영 지침이다
- **인스타그램·스레드 핸들 (스펙 §12)** — 프로필 문구가 도메인만 쓰므로 자산 제작에 영향이 없다

## 완료 조건

- `npm test` 87개 통과
- `npm run build` 성공
- 개발 서버에서 `/brand`가 자산 8종을 렌더하고 PNG로 내보낸다
- 프로덕션 빌드에서 `/brand`가 404
- 내보낸 PNG가 저장소에 없다
