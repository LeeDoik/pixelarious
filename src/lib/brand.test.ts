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
  SHORTS_SAFE_RATIO,
  drawPost,
  POST_LABELS,
  type BrandCanvas,
} from './brand'

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
})
