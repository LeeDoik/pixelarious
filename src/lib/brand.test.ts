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
