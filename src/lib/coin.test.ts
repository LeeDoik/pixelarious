import { describe, it, expect } from 'vitest'
import { drawCoin, COIN_TONES, COIN_SIZE } from './coin'
import type { Palette } from './scenes'

function fakeCanvas() {
  const calls: [string, number, number][] = []
  const ctx = {
    fillStyle: '',
    clearRect() {},
    fillRect(x: number, y: number) {
      calls.push([String(this.fillStyle), x, y])
    },
  }
  return {
    canvas: { width: COIN_SIZE, height: COIN_SIZE, getContext: () => ctx } as never,
    calls,
  }
}

describe('drawCoin', () => {
  it('두 팔레트 모두 그린다', () => {
    for (const palette of ['night', 'dmg'] as Palette[]) {
      const { canvas, calls } = fakeCanvas()
      drawCoin(canvas, palette)
      expect(calls.length, palette).toBeGreaterThan(80)
    }
  })

  it('네 계조만 쓴다 — 색을 아껴야 덩어리로 읽힌다', () => {
    for (const palette of ['night', 'dmg'] as Palette[]) {
      const allowed = new Set(Object.values(COIN_TONES[palette]))
      const { canvas, calls } = fakeCanvas()
      drawCoin(canvas, palette)
      for (const [color] of calls) {
        expect(allowed.has(color), `${palette} used ${color}`).toBe(true)
      }
    }
  })

  it('dmg는 게임보이 4색만 쓴다', () => {
    const allowed = new Set(['#081820', '#346856', '#88C070', '#E0F8D0'])
    const { canvas, calls } = fakeCanvas()
    drawCoin(canvas, 'dmg')
    for (const [color] of calls) expect(allowed.has(color)).toBe(true)
  })

  it('모서리는 비운다 — 사각형이 아니라 원이어야 한다', () => {
    const { canvas, calls } = fakeCanvas()
    drawCoin(canvas, 'night')
    const painted = new Set(calls.map(([, x, y]) => `${x},${y}`))
    for (const p of ['0,0', '15,0', '0,15', '15,15']) {
      expect(painted.has(p), `corner ${p} painted`).toBe(false)
    }
    expect(painted.has('8,8')).toBe(true)
  })

  it('getContext가 null이어도 터지지 않는다', () => {
    const canvas = { width: 16, height: 16, getContext: () => null } as never
    expect(() => drawCoin(canvas, 'night')).not.toThrow()
  })
})
