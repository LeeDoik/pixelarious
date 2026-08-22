import { describe, it, expect } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'
import { drawFavicon, type BrandCanvas } from '@/lib/brand'

/**
 * 탭 아이콘은 16~32px로 보인다. 그 크기에서는 글자를 빼고 커서 블록만 남긴다 —
 * 스펙 §4.1이고, 그것을 그리는 함수가 drawFavicon이다.
 *
 * icon.svg는 손으로 쓴 파일이라 팔레트나 비율이 바뀌면 조용히 어긋난다. 렌더러가
 * 그리는 것과 같은지 여기서 붙잡는다.
 */
const ICON = path.join(process.cwd(), 'src', 'app', 'icon.svg')

/** fillRect만 기록하면 되는 최소 캔버스. brand.test.ts의 것을 가져오면 그쪽 스위트가 같이 돈다. */
function recorder(width: number, height: number) {
  const rects: { color: string; x: number; y: number; w: number; h: number }[] = []
  const ctx = {
    fillStyle: '',
    font: '',
    textBaseline: '',
    imageSmoothingEnabled: true,
    fillRect(x: number, y: number, w: number, h: number) {
      rects.push({ color: String(this.fillStyle), x, y, w, h })
    },
    fillText() {},
    drawImage() {},
  }
  return { canvas: { width, height, getContext: () => ctx } as unknown as BrandCanvas, rects }
}

function svgRects(svg: string) {
  return [...svg.matchAll(/<rect\b[^>]*\/>/g)].map((m) => {
    const attr = (name: string) => m[0].match(new RegExp(" " + name + '="([^"]+)"'))?.[1] ?? null
    return {
      color: attr('fill') ?? '',
      x: Number(attr('x')),
      y: Number(attr('y')),
      w: Number(attr('width')),
      h: Number(attr('height')),
    }
  })
}

describe('사이트 탭 아이콘', () => {
  it('icon.svg가 drawFavicon의 32px 렌더와 사각형 하나까지 같다', () => {
    const { canvas, rects } = recorder(32, 32)
    drawFavicon(canvas)
    expect(svgRects(fs.readFileSync(ICON, 'utf8'))).toEqual(rects)
  })

  it('32 뷰박스에 crispEdges — 어느 크기로 늘려도 픽셀 경계가 흐려지지 않는다', () => {
    const svg = fs.readFileSync(ICON, 'utf8')
    expect(svg).toMatch(/viewBox="0 0 32 32"/)
    expect(svg).toMatch(/shape-rendering="crispEdges"/)
  })
})
