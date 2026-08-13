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

  it('night palette uses only NIGHT colors', () => {
    const allowed = new Set(['#141127', '#0C0A1C', '#1D2B53', '#FFF1E8', '#8E99D9', '#FF77A8', '#29ADFF', '#FFEC27'])
    for (const scene of COVER_SCENES) {
      const { canvas, calls } = fakeCanvas()
      drawScene(canvas, scene, 'night')
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
