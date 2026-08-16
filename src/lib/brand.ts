/**
 * 브랜드 자산 렌더링 — /brand 라우트에서 PNG로 내보낸다.
 *
 * 이 모듈은 DOM에 의존하지 않는다. 캔버스처럼 생긴 객체만 받으므로
 * scenes.test.ts와 같은 방식으로 전부 단위 테스트할 수 있다.
 * 팔레트와 폰트는 사이트(globals.css)와 같은 값이어야 한다 — 스펙 §4.2, §7.
 */

import { rng } from './scenes'

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

/**
 * 실측 기반으로 텍스트가 availWidth 안에 들어올 때까지 폰트 크기를 8px 단위로 줄인다.
 * NeoDGM처럼 한글이 섞인 폰트는 실제 전진폭이 나이브 추정치와 크게 다를 수 있으므로,
 * 테스트의 길이 기반 추정이 아니라 그리기 코드 자체가 안전 영역을 보장해야 한다.
 * ctx.font는 측정을 위해 이 함수 안에서 갱신되며, 반환값을 그대로 그리기에 쓰면 된다.
 */
function fitPixelFont(
  ctx: CanvasRenderingContext2D,
  fontFamily: string,
  text: string,
  size: number,
  availWidth: number,
): number {
  let fitted = size
  ctx.font = `${fitted}px ${fontFamily}`
  while (fitted > 8 && textWidth(ctx, text, fitted) > availWidth) {
    fitted = pixelFontSize(fitted - 8)
    ctx.font = `${fitted}px ${fontFamily}`
  }
  return fitted
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

  // 워드마크와 태그라인 — 안전 영역 오른쪽 경계까지의 실제 여유폭을 실측해서 넘치면 줄인다
  const textX = left + tile + Math.round(tile * 0.22)
  const availWidth = left + YT_SAFE.w - textX
  ctx.textBaseline = 'middle'

  const wordText = 'PIXELARIOUS'
  fitPixelFont(ctx, DISPLAY_FONT, wordText, pixelFontSize(YT_SAFE.w * 0.055), availWidth)
  ctx.fillStyle = BRAND.text
  const wordY = Math.round(top + YT_SAFE.h * 0.42)
  ctx.fillText(wordText, textX, wordY)

  const tagText = '브라우저에서 바로 플레이 · PLAY IN YOUR BROWSER'
  fitPixelFont(ctx, BODY_FONT, tagText, pixelFontSize(YT_SAFE.w * 0.022), availWidth)
  ctx.fillStyle = BRAND.dim
  ctx.fillText(tagText, textX, Math.round(top + YT_SAFE.h * 0.72))

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
