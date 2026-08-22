import type { Palette } from './scenes'

/**
 * 아케이드 토큰을 16x16 픽셀로 그린다. 커버 아트와 같은 방식이다 — 작은 캔버스에
 * 픽셀을 찍고 image-rendering:pixelated로 정수배 확대한다. CSS 그라데이션으로
 * 만든 동전은 매끈해서 픽셀 게임의 물건으로 보이지 않는다.
 *
 * 계조는 네 단계뿐이다: 하이라이트 / 면 / 그늘 / 테두리. 옛날 스프라이트가
 * 그랬듯 색을 아껴야 덩어리로 읽힌다.
 */

export const COIN_SIZE = 16

/** 동전 면에 찍히는 달러 기호. 세로획이 S 위아래로 튀어나오는 그 모양. */
const DOLLAR = [
  '..#..',
  '.###.',
  '#.#..',
  '.###.',
  '..#.#',
  '.###.',
  '..#..',
] as const
const GLYPH_X = 5
const GLYPH_Y = 4

interface CoinTones {
  /** 가장 밝은 면과 반짝임 */
  hi: string
  /** 기본 면 */
  base: string
  /** 그늘진 아래쪽 */
  shade: string
  /** 바깥 테두리와 각인 */
  line: string
}

export const COIN_TONES: Record<Palette, CoinTones> = {
  night: { hi: '#FFF1E8', base: '#FFEC27', shade: '#C79A1E', line: '#0C0A1C' },
  dmg: { hi: '#E0F8D0', base: '#88C070', shade: '#346856', line: '#081820' },
}

type MinimalCanvas = {
  width: number
  height: number
  getContext(id: '2d'): CanvasRenderingContext2D | null
}

/** 반지름 밖은 투명, 안쪽은 광원(왼쪽 위)에 따라 네 계조로 나눈다 */
export function drawCoin(canvas: MinimalCanvas, palette: Palette): void {
  const ctx = canvas.getContext('2d')
  if (!ctx) return
  const t = COIN_TONES[palette]
  const N = COIN_SIZE
  const c = (N - 1) / 2

  ctx.clearRect(0, 0, N, N)
  const px = (x: number, y: number, color: string) => {
    ctx.fillStyle = color
    ctx.fillRect(x, y, 1, 1)
  }

  for (let y = 0; y < N; y++) {
    for (let x = 0; x < N; x++) {
      const dx = x - c
      const dy = y - c
      const r = Math.hypot(dx, dy)
      if (r > 7.4) continue // 동전 바깥
      const lit = dx + dy // 광원은 왼쪽 위

      if (r > 6.3) {
        px(x, y, t.line) // 바깥 테두리
      } else if (r > 5.05) {
        // 테두리 링 — 위쪽은 빛을 받고 아래쪽은 그늘진다.
        // 이 띠에만 하이라이트를 주어야 면이 금색으로 남는다.
        px(x, y, lit < 0 ? t.hi : t.shade)
      } else {
        // 면은 기본색. 오른쪽 아래만 한 계조 떨어뜨려 부피를 준다
        px(x, y, lit > 2.6 ? t.shade : t.base)
      }
    }
  }

  // 가운데 각인 — 5x7 달러 기호
  DOLLAR.forEach((row, ry) => {
    for (let rx = 0; rx < row.length; rx++) {
      if (row[rx] === '#') px(GLYPH_X + rx, GLYPH_Y + ry, t.line)
    }
  })

  // 반짝임 — 면 위 왼쪽 위에 찍힌 작은 점
  px(5, 4, t.hi)
  px(4, 5, t.hi)
  px(5, 5, t.hi)
}
