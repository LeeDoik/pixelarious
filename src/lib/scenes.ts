export type CoverScene = 'starfall' | 'cave' | 'pong' | 'system' | 'lastlogin'
export const COVER_SCENES: CoverScene[] = ['starfall', 'cave', 'pong', 'system', 'lastlogin']
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
    lastlogin: { sky: '#0C0A1C', far: '#1D2B53', star: '#8E99D9', hi: '#FFEC27', obj: '#FFF1E8', obj2: '#29ADFF' },
  },
  dmg: {
    starfall: { sky: '#081820', far: '#346856', star: '#E0F8D0', hi: '#E0F8D0', obj: '#88C070', obj2: '#E0F8D0' },
    cave: { sky: '#081820', far: '#346856', star: '#88C070', hi: '#E0F8D0', obj: '#88C070', obj2: '#E0F8D0' },
    pong: { sky: '#081820', far: '#346856', star: '#88C070', hi: '#E0F8D0', obj: '#E0F8D0', obj2: '#88C070' },
    system: { sky: '#081820', far: '#346856', star: '#88C070', hi: '#E0F8D0', obj: '#88C070', obj2: '#E0F8D0' },
    lastlogin: { sky: '#081820', far: '#346856', star: '#88C070', hi: '#E0F8D0', obj: '#E0F8D0', obj2: '#88C070' },
  },
}

const SEEDS: Record<CoverScene, number> = { starfall: 7, cave: 23, pong: 41, system: 77, lastlogin: 59 }

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

  if (scene === 'lastlogin') {
    // 어두운 방 — 화면 밖으로 번지는 빛 말고는 아무것도 없다
    for (let i = 0; i < 14; i++) px((r() * W) | 0, (r() * H) | 0, 1, 1, p.star)

    // CRT 모니터 본체 — 중앙에서 살짝 오른쪽으로 치우친 베이지색 박스
    px(36, 10, 34, 22, p.obj)
    px(38, 12, 30, 4, p.far)

    // 화면 — 꺼지지 않은 골드 텍스트 라인이 어둠 속에서 빛난다
    px(40, 16, 26, 12, p.far)
    px(42, 18, 14, 1, p.hi)
    px(42, 21, 20, 1, p.hi)
    px(42, 24, 10, 1, p.hi)
    px(42, 27, 16, 1, p.obj2)
    px(39, 15, 1, 14, p.obj2)
    px(66, 15, 1, 14, p.obj2)

    // 받침대
    px(48, 32, 12, 3, p.far)
    px(44, 35, 20, 2, p.obj)

    // 키보드 — 모니터 아래 얕게 놓인 막대
    px(30, 39, 44, 3, p.star)
    for (let x = 32; x < 72; x += 3) px(x, 40, 1, 1, p.far)

    // 전원 표시등
    px(63, 29, 2, 2, p.hi)
  }
}
