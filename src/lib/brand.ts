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
