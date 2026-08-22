import { describe, it, expect } from 'vitest'
import {
  BRAND,
  SCANLINE,
  drawMark,
  drawProfile,
  drawFavicon,
  pixelFontSize,
  drawYouTubeBanner,
  drawShortsCard,
  YT_SAFE,
  unitFor,
  SHORTS_SAFE_RATIO,
  drawPost,
  POST_LABELS,
  type BrandCanvas,
} from './brand'

export function fakeCanvas(width: number, height: number) {
  const rects: { color: string; x: number; y: number; w: number; h: number }[] = []
  const texts: { color: string; text: string; x: number; y: number; font: string }[] = []
  const images: {
    img: unknown
    x: number
    y: number
    w: number
    h: number
    smoothing: boolean
  }[] = []
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
    drawImage(img: unknown, x: number, y: number, w: number, h: number) {
      images.push({ img, x, y, w, h, smoothing: this.imageSmoothingEnabled })
    },
  }
  return {
    canvas: { width, height, getContext: () => ctx } as unknown as BrandCanvas,
    rects,
    texts,
    images,
  }
}

const NIGHT: Set<string> = new Set(Object.values(BRAND))

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

describe('drawYouTubeBanner', () => {
  it('keeps every logo and text pixel inside the safe area', () => {
    const { canvas, rects, texts } = fakeCanvas(2560, 1440)
    drawYouTubeBanner(canvas)
    const left = (2560 - YT_SAFE.w) / 2
    const top = (1440 - YT_SAFE.h) / 2
    const right = left + YT_SAFE.w
    const bottom = top + YT_SAFE.h
    // 배경·별·스캔라인과 마크 타일의 deep 배경은 전면을 덮어도 된다. 여기서는 안전 영역보다
    // 좁은 금색 커서 사각형과 글자 위치만 검사한다.
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

  it('shrinks the tagline when real glyph metrics would overflow the safe area', () => {
    // fakeCanvas has no measureText, so it can never exercise the shrink branch — the
    // naive text.length*fontSize estimate is exactly what the fit loop is meant to
    // distrust. This stub reports a measureText width that is deliberately much wider
    // than that estimate (standing in for NeoDGM's real, wider Korean advance widths),
    // forcing drawYouTubeBanner to actually shrink the font instead of just assuming it fits.
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
      measureText(text: string) {
        const size = parseInt(String(this.font), 10) || 0
        // 3x the naive length*fontSize estimate — wide enough to force the fit loop to shrink.
        return { width: text.length * size * 3 }
      },
    }
    const canvas = { width: 2560, height: 1440, getContext: () => ctx } as unknown as BrandCanvas

    drawYouTubeBanner(canvas)

    const left = (2560 - YT_SAFE.w) / 2
    const top = (1440 - YT_SAFE.h) / 2
    const right = left + YT_SAFE.w
    const bottom = top + YT_SAFE.h

    const tagline = texts.find((t) => t.text.includes('PLAY IN YOUR BROWSER'))
    expect(tagline).toBeDefined()
    const shrunkSize = parseInt(tagline!.font, 10)
    const defaultSize = pixelFontSize(YT_SAFE.w * 0.022)
    expect(shrunkSize).toBeLessThan(defaultSize)

    // it must still fit inside the safe area under the same inflated metric that forced the shrink
    const measuredWidth = tagline!.text.length * shrunkSize * 3
    expect(tagline!.x >= left && tagline!.x + measuredWidth <= right, 'shrunk tagline still overflows').toBe(
      true,
    )
    expect(tagline!.y - shrunkSize >= top && tagline!.y + shrunkSize <= bottom).toBe(true)
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

  it('shrinks a long headline so it stays centred inside the canvas instead of clipping', () => {
    // fakeCanvas has no measureText, so it can never exercise the shrink branch — same gap as
    // the other shrink tests in this file. This stub reports a measureText width 3x the naive
    // length*fontSize estimate, forcing drawShortsCard to actually shrink the headline instead
    // of assuming the centred line fits inside the frame.
    const texts: { color: string; text: string; x: number; y: number; font: string }[] = []
    const ctx = {
      fillStyle: '',
      font: '',
      textBaseline: '',
      imageSmoothingEnabled: true,
      fillRect() {},
      fillText(text: string, x: number, y: number) {
        texts.push({ color: String(this.fillStyle), text, x, y, font: String(this.font) })
      },
      drawImage() {},
      measureText(text: string) {
        const size = parseInt(String(this.font), 10) || 0
        return { width: text.length * size * 3 }
      },
    }
    const canvas = { width: 1080, height: 1920, getContext: () => ctx } as unknown as BrandCanvas

    drawShortsCard(canvas, ['새 업데이트가 방금 나왔습니다'])

    const W = 1080
    const defaultSize = pixelFontSize(W * 0.075)
    const headlineText = texts.find((t) => t.text === '새 업데이트가 방금 나왔습니다')
    expect(headlineText).toBeDefined()
    const shrunkSize = parseInt(headlineText!.font, 10)
    expect(shrunkSize).toBeLessThan(defaultSize)

    const pad = Math.round(W * 0.075)
    const measuredWidth = headlineText!.text.length * shrunkSize * 3
    expect(
      headlineText!.x,
      'shrunk headline starts left of the padded margin',
    ).toBeGreaterThanOrEqual(pad)
    expect(
      headlineText!.x + measuredWidth,
      'shrunk headline still clips past the right margin',
    ).toBeLessThanOrEqual(W - pad)
  })
})

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

  it('shrinks the title so it clears the watermark instead of colliding with it', () => {
    // fakeCanvas has no measureText, so it can never exercise the shrink branch — same gap as
    // the YouTube tagline / cartridge title tests above. This stub reports a measureText width
    // 3x the naive length*fontSize estimate, forcing drawFullBleed to actually shrink the title
    // instead of relying on horizontal luck to keep it clear of the watermark.
    const texts: { color: string; text: string; x: number; y: number; font: string }[] = []
    const ctx = {
      fillStyle: '',
      font: '',
      textBaseline: '',
      imageSmoothingEnabled: true,
      fillRect() {},
      fillText(text: string, x: number, y: number) {
        texts.push({ color: String(this.fillStyle), text, x, y, font: String(this.font) })
      },
      drawImage() {},
      measureText(text: string) {
        const size = parseInt(String(this.font), 10) || 0
        return { width: text.length * size * 3 }
      },
    }
    const canvas = { width: 1080, height: 1080, getContext: () => ctx } as unknown as BrandCanvas

    drawPost(canvas, {
      kind: 'full',
      label: 'NEW GAME',
      title: ['DOWN THE CAVE'],
      image: null,
    })

    const W = 1080
    const defaultTitleSize = pixelFontSize(W * 0.062)
    const titleText = texts.find((t) => t.text === 'DOWN THE CAVE')
    expect(titleText).toBeDefined()
    const shrunkSize = parseInt(titleText!.font, 10)
    expect(shrunkSize).toBeLessThan(defaultTitleSize)

    // recompute the watermark's left edge under the same inflated metric that forced the
    // shrink — matches watermarkStartX in brand.ts (tile + 30% gap + measured name width).
    const pad = Math.round(W * 0.055)
    const tile = Math.round(W * 0.055)
    const wmPad = Math.round(W * 0.03)
    const nameSize = pixelFontSize(W * 0.016)
    const nameW = Math.round('PIXELARIOUS'.length * nameSize * 3)
    const wmX = W - wmPad - (tile + Math.round(tile * 0.3) + nameW)

    const measuredWidth = titleText!.text.length * shrunkSize * 3
    expect(
      titleText!.x + measuredWidth,
      'shrunk title still reaches the watermark',
    ).toBeLessThanOrEqual(wmX)
    expect(titleText!.x).toBeGreaterThanOrEqual(pad)
  })
})

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
    // 회귀가 spec.subtitle이 undefined인 채로 fillText를 여전히 호출한다면 mock은
    // text: undefined를 기록한다 — '' 검사만으로는 이를 못 잡는다. 직접 증명한다.
    expect(texts.some((t) => t.text === undefined)).toBe(false)

    // 같은 스펙에 subtitle만 추가하면 텍스트 그리기 호출 수가 실제로 늘어나야 한다 —
    // subtitle 라인이 조건에 따라 하나 더(또는 덜) 그려졌음을 직접 증명한다.
    const withSub = fakeCanvas(1080, 1080)
    drawPost(withSub.canvas, {
      kind: 'cartridge',
      index: 0,
      title: 'PIXEL PONG.EXE',
      subtitle: '픽셀퐁',
      description: '하루 만에 만든 퐁 변형.',
      tags: [],
      cover: null,
    })
    expect(withSub.texts.length).toBeGreaterThan(texts.length)
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

  it('shrinks a long title so it stays inside the box instead of overflowing', () => {
    const { canvas, texts } = fakeCanvas(1080, 1080)
    // The flagship title from the brief: at W=1080 the default titleSize (32px) times
    // 14 chars (PS2P is 1em/char) is 448px, but textX(568)..boxX+boxW(1004) only leaves
    // 436px — it would overflow by design unless the fitting loop shrinks it.
    drawPost(canvas, {
      kind: 'cartridge',
      index: 0,
      title: 'STARFALL DRIFT',
      description: 'y',
      tags: [],
      cover: null,
    })
    const titleText = texts.find((t) => t.text === 'STARFALL DRIFT')
    expect(titleText).toBeDefined()

    const defaultTitleSize = pixelFontSize(1080 * 0.036) // 32
    const shrunkSize = parseInt(titleText!.font, 10)
    expect(shrunkSize).toBeLessThan(defaultTitleSize)

    // Box's inner right edge at W=1080: pad=76, boxW=928, boxX=76 → boxX+boxW=1004
    // (matches the trace in the review finding).
    const boxInnerRight = 1004
    const measuredWidth = titleText!.text.length * shrunkSize // fakeCanvas has no measureText
    expect(titleText!.x + measuredWidth).toBeLessThanOrEqual(boxInnerRight)
  })

  it('draws the cover through the shared cover-fit helper, not a raw stretch', () => {
    const { canvas, images } = fakeCanvas(1080, 1080)
    // Deliberately NOT the 100:42 aspect the site's real covers happen to use — this
    // proves the destination rect comes from drawImageCover's cover-fit maths
    // (scale by Math.max, centre the overflow) rather than a plain drawImage stretch,
    // which would coincidentally look right only when the aspect ratios happen to match.
    const cover = { width: 300, height: 100 }
    drawPost(canvas, {
      kind: 'cartridge',
      index: 0,
      title: 'A',
      description: 'b',
      tags: [],
      cover,
    })

    expect(images.length).toBe(1)
    const draw = images[0]
    expect(draw.img).toBe(cover)
    expect(draw.smoothing).toBe(false)

    // Geometry at W=1080: boxX=76, boxW=928, coverW=390, coverH=164,
    // coverX=148, coverY=430 (see the trace in the review finding / drawCartridge).
    // scale = max(390/300, 164/100) = 1.64 → dw=492, dh=164 (not 390×164 — a plain
    // stretch to coverW×coverH — which is exactly what a raw drawImage would produce).
    const coverW = 390
    expect(draw.w).toBe(492)
    expect(draw.h).toBe(164)
    expect(draw.w).not.toBe(coverW)
    expect(draw.x).toBe(97)
    expect(draw.y).toBe(430)
  })
})

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

  it('shrinks the log line and headline fonts when real glyph metrics would overflow the row', () => {
    // fakeCanvas has no measureText, so it can never exercise the shrink branch — same gap
    // as the YouTube tagline test above. This stub reports a measureText width 3x the naive
    // length*fontSize estimate, forcing drawTerminal to actually shrink instead of assuming
    // the log line, status and headline fit.
    const texts: { color: string; text: string; x: number; y: number; font: string }[] = []
    const ctx = {
      fillStyle: '',
      font: '',
      textBaseline: '',
      imageSmoothingEnabled: true,
      fillRect() {},
      fillText(text: string, x: number, y: number) {
        texts.push({ color: String(this.fillStyle), text, x, y, font: String(this.font) })
      },
      drawImage() {},
      measureText(text: string) {
        const size = parseInt(String(this.font), 10) || 0
        return { width: text.length * size * 3 }
      },
    }
    const canvas = { width: 1080, height: 1080, getContext: () => ctx } as unknown as BrandCanvas

    drawPost(canvas, {
      kind: 'terminal',
      label: 'DEV LOG',
      log: [
        {
          text: '> BUILD v0.3.1-regression',
          status: '... CHANGED',
          tone: 'gold',
        },
      ],
      headline: ['다음 업데이트에서 조명 반경이 훨씬 크게 줄어듭니다'],
    })

    const pad = Math.round(1080 * 0.075)
    const right = 1080 - pad

    const logText = texts.find((t) => t.text.startsWith('> BUILD'))
    expect(logText).toBeDefined()
    const defaultLogSize = pixelFontSize(1080 * 0.022)
    const shrunkLogSize = parseInt(logText!.font, 10)
    expect(shrunkLogSize).toBeLessThan(defaultLogSize)

    // the status is drawn right after the log text at its measured (inflated) width — the
    // sum of the two must still land inside the padded safe area under the same inflated
    // metric that forced the shrink.
    const statusText = texts.find((t) => t.text === '... CHANGED')
    expect(statusText).toBeDefined()
    const measuredStatusWidth = statusText!.text.length * shrunkLogSize * 3
    expect(statusText!.x + measuredStatusWidth, 'shrunk log line still overflows').toBeLessThanOrEqual(
      right,
    )

    const headlineText = texts.find((t) => t.text.startsWith('다음 업데이트'))
    expect(headlineText).toBeDefined()
    const defaultHeadSize = pixelFontSize(1080 * 0.062)
    const shrunkHeadSize = parseInt(headlineText!.font, 10)
    expect(shrunkHeadSize).toBeLessThan(defaultHeadSize)
    const measuredHeadWidth = headlineText!.text.length * shrunkHeadSize * 3
    expect(
      headlineText!.x + measuredHeadWidth,
      'shrunk headline still overflows',
    ).toBeLessThanOrEqual(right)
  })

  it.each([
    [1080, 1080],
    [1080, 1350],
  ])(
    'shrinks the log font and clamps the block above the watermark when the log runs long (%ix%i)',
    (W, H) => {
      const { canvas, rects, texts } = fakeCanvas(W, H)
      // 1080x1350 has more vertical headroom than 1080x1080, so the log needs enough lines to
      // overflow the taller canvas too — not just the square one.
      const log = Array.from({ length: 30 }, (_, i) => ({
        text: `> STEP ${i}`,
        status: 'OK',
        tone: 'ok' as const,
      }))
      drawPost(canvas, {
        kind: 'terminal',
        label: 'DEV LOG',
        log,
        headline: ['헤드라인 첫줄', '헤드라인 둘째줄'],
      })

      const defaultLogSize = pixelFontSize(W * 0.022)
      const logText = texts.find((t) => t.text === '> STEP 0')
      expect(logText).toBeDefined()
      const shrunkLogSize = parseInt(logText!.font, 10)
      expect(shrunkLogSize, 'log font must shrink to make room').toBeLessThan(defaultLogSize)

      const pad = Math.round(W * 0.075)
      const wmTile = Math.round(W * 0.055)
      const wmPad = Math.round(W * 0.03)
      const watermarkTop = H - wmPad - wmTile

      const lastHeadline = texts.find((t) => t.text === '헤드라인 둘째줄')
      expect(lastHeadline).toBeDefined()
      const headSize = parseInt(lastHeadline!.font, 10)
      // textBaseline is 'middle', so the line's own bottom edge is y + size/2.
      expect(
        lastHeadline!.y + headSize / 2,
        'last headline line reaches the watermark band',
      ).toBeLessThanOrEqual(watermarkTop)
      expect(lastHeadline!.y + headSize / 2).toBeLessThanOrEqual(H)

      const cursor = rects.find(
        (r) => r.color === BRAND.gold && r.h === headSize && r.w === Math.round(headSize * 0.62),
      )
      expect(cursor, 'headline cursor block not found').toBeDefined()
      expect(cursor!.y + cursor!.h, 'cursor reaches the watermark band').toBeLessThanOrEqual(
        watermarkTop,
      )
      expect(cursor!.y + cursor!.h).toBeLessThanOrEqual(H)
      expect(cursor!.x, 'cursor stays left of the padded margin').toBeGreaterThanOrEqual(pad)
    },
  )
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

  it('shrinks a long question line when real glyph metrics would overflow the row', () => {
    // Same gap as the YouTube tagline / terminal shrink tests — fakeCanvas has no
    // measureText, so this stub reports a width 3x the naive length*fontSize estimate to
    // force drawQuestion to actually shrink instead of assuming the line fits.
    const texts: { color: string; text: string; x: number; y: number; font: string }[] = []
    const ctx = {
      fillStyle: '',
      font: '',
      textBaseline: '',
      imageSmoothingEnabled: true,
      fillRect() {},
      fillText(text: string, x: number, y: number) {
        texts.push({ color: String(this.fillStyle), text, x, y, font: String(this.font) })
      },
      drawImage() {},
      measureText(text: string) {
        const size = parseInt(String(this.font), 10) || 0
        return { width: text.length * size * 3 }
      },
    }
    const canvas = { width: 1080, height: 1080, getContext: () => ctx } as unknown as BrandCanvas

    drawPost(canvas, {
      kind: 'question',
      label: 'YOUR TURN',
      question: ['다음 업데이트에서는 어떤 기능을 가장 먼저 보고 싶으신가요?'],
    })

    const pad = Math.round(1080 * 0.075)
    const right = 1080 - pad

    const qText = texts.find((t) => t.text.startsWith('다음 업데이트'))
    expect(qText).toBeDefined()
    const defaultQSize = pixelFontSize(1080 * 0.085)
    const shrunkQSize = parseInt(qText!.font, 10)
    expect(shrunkQSize).toBeLessThan(defaultQSize)

    const measuredWidth = qText!.text.length * shrunkQSize * 3
    expect(qText!.x + measuredWidth, 'shrunk question line still overflows').toBeLessThanOrEqual(
      right,
    )
  })

  it.each([
    [1080, 1080],
    [1080, 1350],
  ])(
    'shrinks a long question so its centred block clears the watermark band (%ix%i)',
    (W, H) => {
      const { canvas, texts } = fakeCanvas(W, H)
      const question = Array.from({ length: 9 }, (_, i) => `질문 줄 ${i}`)
      drawPost(canvas, { kind: 'question', label: 'YOUR TURN', question })

      const defaultQSize = pixelFontSize(W * 0.085)
      const lines = question.map((q) => texts.find((t) => t.text === q))
      for (const l of lines) expect(l).toBeDefined()
      const shrunkQSize = parseInt(lines[0]!.font, 10)
      expect(shrunkQSize, 'question font must shrink to make room').toBeLessThan(defaultQSize)

      const wmTile = Math.round(W * 0.055)
      const wmPad = Math.round(W * 0.03)
      const watermarkTop = H - wmPad - wmTile

      const last = lines[lines.length - 1]!
      expect(
        last.y + shrunkQSize / 2,
        'last question line reaches the watermark band',
      ).toBeLessThanOrEqual(watermarkTop)
      expect(last.y + shrunkQSize / 2).toBeLessThanOrEqual(H)
    },
  )
})

describe('배경 아트 — 디더 성운과 별 배치', () => {
  it('banner leaves the safe area free of stars so the logo sits on empty dark', () => {
    const { canvas, rects } = fakeCanvas(2560, 1440)
    drawYouTubeBanner(canvas)
    const left = (2560 - YT_SAFE.w) / 2
    const top = (1440 - YT_SAFE.h) / 2
    // 별은 text/dim 색이고 마크 타일보다 작다. 안전 영역 안에 하나도 없어야 한다.
    const stars = rects.filter(
      (r) => (r.color === BRAND.text || r.color === BRAND.dim) && r.w <= 40,
    )
    expect(stars.length).toBeGreaterThan(0)
    for (const s of stars) {
      const overlaps =
        s.x + s.w > left && s.x < left + YT_SAFE.w && s.y + s.h > top && s.y < top + YT_SAFE.h
      expect(overlaps, `star at ${s.x},${s.y} sits inside the safe area`).toBe(false)
    }
  })

  it('banner dithers a nebula band that stays in the lower part of the frame', () => {
    const { canvas, rects } = fakeCanvas(2560, 1440)
    drawYouTubeBanner(canvas)
    const band = rects.filter((r) => r.color === BRAND.surface)
    expect(band.length).toBeGreaterThan(50)
    // 상단 절반에는 성운이 올라오지 않는다
    expect(band.every((r) => r.y >= 1440 * 0.55)).toBe(true)
  })

  it('shorts keeps stars out of the UI-covered bottom quarter', () => {
    const { canvas, rects } = fakeCanvas(1080, 1920)
    drawShortsCard(canvas, ['가'])
    const floor = 1920 * SHORTS_SAFE_RATIO
    const stars = rects.filter(
      (r) => (r.color === BRAND.text || r.color === BRAND.dim) && r.w <= 40,
    )
    expect(stars.length).toBeGreaterThan(0)
    for (const s of stars) {
      expect(s.y + s.h <= floor, `star reaches ${s.y + s.h}`).toBe(true)
    }
  })

  it('full-bleed without a screenshot paints the field, not a flat rectangle', () => {
    const { canvas, rects } = fakeCanvas(1080, 1080)
    drawPost(canvas, { kind: 'full', label: 'NEW GAME', title: ['A'], image: null })
    // 예전에는 BRAND.bg 단색 하나였다. 이제 디더 셀과 별이 있어야 한다.
    expect(rects.some((r) => r.color === BRAND.surface)).toBe(true)
    const stars = rects.filter(
      (r) => (r.color === BRAND.text || r.color === BRAND.dim) && r.w <= 40,
    )
    expect(stars.length).toBeGreaterThan(0)
    // 하단 40%는 라벨·제목·워터마크 자리다
    for (const s of stars) expect(s.y + s.h <= 1080 * 0.6 + 1).toBe(true)
  })
})

describe('배경 아트 — 성운의 결', () => {
  const cellsOf = (rects: { color: string; x: number; y: number; w: number; h: number }[], W: number) =>
    rects.filter((r) => (r.color === BRAND.surface || r.color === BRAND.bg) && r.w < W)

  it('성운 경계가 자로 그은 직선이 아니다', () => {
    const { canvas, rects } = fakeCanvas(2560, 1440)
    drawYouTubeBanner(canvas)
    // 열마다 성운이 시작되는 높이를 모은다. 밀도가 세로 램프뿐이면 모든 열이 같은
    // 높이에서 시작해 띠의 경계가 캔버스를 가로지르는 한 줄로 보인다.
    const topByColumn = new Map<number, number>()
    for (const c of cellsOf(rects, 2560)) {
      const prev = topByColumn.get(c.x)
      if (prev === undefined || c.y < prev) topByColumn.set(c.x, c.y)
    }
    expect(new Set(topByColumn.values()).size).toBeGreaterThan(10)
  })

  it('가로로도 밀도가 변한다 — 네 열 주기로 똑같이 반복되지 않는다', () => {
    const { canvas, rects } = fakeCanvas(2560, 1440)
    drawYouTubeBanner(canvas)
    const step = unitFor(2560, 1440) * 4
    const count = new Map<number, number>()
    for (const c of cellsOf(rects, 2560)) count.set(c.x, (count.get(c.x) ?? 0) + 1)
    const xs = [...count.keys()].sort((a, b) => a - b)
    // Bayer 4x4는 네 열마다 되풀이된다. 밀도가 x와 무관하면 x와 x+4셀의 개수가
    // 항상 정확히 같아서 무늬가 직조된 천처럼 읽힌다.
    let differs = 0
    for (const x of xs) {
      const next = count.get(x + step)
      if (next !== undefined && next !== count.get(x)) differs++
    }
    expect(differs).toBeGreaterThan(xs.length * 0.5)
  })

  it('성운이 두 톤으로 깊이를 만든다 — 짙은 속과 옅은 둘레', () => {
    const { canvas, rects } = fakeCanvas(2560, 1440)
    drawYouTubeBanner(canvas)
    expect(rects.some((r) => r.color === BRAND.surface && r.w < 2560)).toBe(true)
    expect(rects.some((r) => r.color === BRAND.bg && r.w < 2560)).toBe(true)
  })

  it('쇼츠 마크가 성운 위에 검은 판을 찍지 않는다', () => {
    const { canvas, rects } = fakeCanvas(1080, 1920)
    drawShortsCard(canvas, ['가'])
    // 배경 전면을 칠하는 한 장 말고 deep 사각형이 더 있으면 그건 마크 판이다.
    expect(rects.filter((r) => r.color === BRAND.deep && r.w < 1080)).toHaveLength(0)
  })
})
