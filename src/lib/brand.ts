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
/** 별 하나가 담당하는 캔버스 면적. 클수록 하늘이 성겨진다. */
const STAR_AREA_PER_PIXEL = 26000

/**
 * 4x4 순서 디더 행렬(Bayer). 8색 팔레트에서 톤 전이를 만드는 유일한 방법이다 —
 * 부드러운 그라데이션은 팔레트를 벗어나므로 쓸 수 없다.
 */
const BAYER4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
]

/** 로고나 문구가 올라갈 자리 — 여기엔 배경 요소를 두지 않는다. */
export interface Rect {
  x: number
  y: number
  w: number
  h: number
}

function inside(rect: Rect, x: number, y: number, size: number): boolean {
  return x + size > rect.x && x < rect.x + rect.w && y + size > rect.y && y < rect.y + rect.h
}

/**
 * 세로 방향 디더 그라데이션. densityAt(t)가 0이면 아무것도 안 그리고 1이면 꽉 채운다.
 * 배경색 위에 색 셀만 얹으므로 밀도가 낮은 구간은 순회 비용도 들지 않는다.
 */
function drawDitherGradient(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
  cell: number,
  color: string,
  densityAt: (t: number) => number,
): void {
  const cols = Math.ceil(w / cell)
  const rows = Math.ceil(h / cell)
  ctx.fillStyle = color
  for (let ry = 0; ry < rows; ry++) {
    const density = densityAt(rows > 1 ? ry / (rows - 1) : 0)
    if (density <= 0) continue
    const threshold = density * 16
    const row = BAYER4[ry & 3]
    for (let rx = 0; rx < cols; rx++) {
      if (row[rx & 3] < threshold) ctx.fillRect(rx * cell, ry * cell, cell, cell)
    }
  }
}

/**
 * 별밭. avoid에 준 사각형들은 비워 둔다 — 로고와 문구가 앉을 자리에 별이 끼면
 * 아무리 성겨도 지저분해 보인다.
 */
function drawStarfield(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
  unit: number,
  seed: number,
  avoid: Rect[] = [],
): void {
  const r = rng(seed)
  // 별은 배경 질감이지 주인공이 아니다. 밀도를 낮게 잡아야 로고가 묻히지 않는다 —
  // 별 하나당 대략 160x160 픽셀을 차지한다.
  const count = Math.round((w * h) / STAR_AREA_PER_PIXEL)
  for (let i = 0; i < count; i++) {
    const x = Math.floor(r() * w)
    const y = Math.floor(r() * h)
    // 소수만 두 배 크기로 두어 밀도를 올리지 않고 원근감을 만든다.
    const near = r() < 0.18
    const size = near ? unit * 2 : unit
    // 금색은 커서 전용이다. 별에 쓰면 안전 영역 검사가 별까지 잡고,
    // 브랜드의 유일한 강조색이 배경 노이즈로 흩어진다.
    const color = near || r() < 0.6 ? BRAND.text : BRAND.dim
    // 비워야 할 자리에 떨어졌으면 그냥 버린다. 밀어내면 경계에 별이 줄지어 선다.
    if (avoid.some((rect) => inside(rect, x, y, size))) continue
    ctx.fillStyle = color
    ctx.fillRect(x, y, size, size)
  }
}

export function drawYouTubeBanner(canvas: BrandCanvas): void {
  const ctx = canvas.getContext('2d')
  if (!ctx) return
  const W = canvas.width
  const H = canvas.height
  const unit = unitFor(W, H)

  const left = Math.round((W - YT_SAFE.w) / 2)
  const top = Math.round((H - YT_SAFE.h) / 2)

  ctx.fillStyle = BRAND.deep
  ctx.fillRect(0, 0, W, H)
  // 아래쪽으로 갈수록 짙어지는 성운 띠. 하단 38%에서만 올라온다.
  drawDitherGradient(ctx, W, H, unit, BRAND.surface, (t) =>
    t < 0.62 ? 0 : ((t - 0.62) / 0.38) * 0.8,
  )
  // 별은 안전 영역 바깥에만 둔다 — 가운데는 로고와 두 줄 문구가 들어갈 자리다.
  drawStarfield(ctx, W, H, unit, 7, [
    { x: left, y: top, w: YT_SAFE.w, h: YT_SAFE.h },
  ])

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
  // 위에서 아래로 내려가며 어둠이 깊어진다. 하단 55%는 완전히 비어 있다.
  drawDitherGradient(ctx, W, H, unit, BRAND.surface, (t) =>
    t > 0.45 ? 0 : ((0.45 - t) / 0.45) * 0.65,
  )
  // 마크 자리(상단)와 앱 UI가 덮는 하단 25%에는 별을 두지 않는다.
  const markTile = Math.round(W * 0.26)
  drawStarfield(ctx, W, H, unit, 23, [
    { x: Math.round((W - markTile) / 2) - unit * 2, y: Math.round(H * 0.14) - unit * 2, w: markTile + unit * 4, h: markTile + unit * 4 },
    { x: 0, y: floor, w: W, h: H - floor },
  ])

  const tile = Math.round(W * 0.26)
  drawMarkInto(ctx, Math.round((W - tile) / 2), Math.round(H * 0.14), tile, tile)

  // 좌우 여백을 남긴 실사용 폭 안에 맞춘다(drawQuestion과 같은 방식) — 긴 헤드라인 한 줄이
  // 캔버스를 양옆으로 넘치는 사고를 막는다.
  const pad = Math.round(W * 0.075)
  const availWidth = W - pad * 2
  let size = pixelFontSize(W * 0.075)
  for (const line of headline) {
    size = Math.min(size, fitPixelFont(ctx, BODY_FONT, line, size, availWidth))
  }
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

export interface CartridgePost {
  kind: 'cartridge'
  /** 0부터 세는 슬롯 인덱스. 화면에는 1부터 두 자리로 표시한다(사이트와 동일). */
  index: number
  title: string
  subtitle?: string
  description: string
  tags: string[]
  /** 미리 렌더한 커버(100×42 캔버스). 없으면 자리를 비운다. */
  cover: BrandImage | null
}

export interface TerminalLine {
  text: string
  status?: string
  tone?: 'ok' | 'gold'
}

export interface TerminalPost {
  kind: 'terminal'
  label: PostLabel
  log: TerminalLine[]
  headline: string[]
}

export interface QuestionPost {
  kind: 'question'
  label: PostLabel
  question: string[]
}

export type PostSpec = FullBleedPost | CartridgePost | TerminalPost | QuestionPost

/** 금색 배지 + 칠흑 글자. 게시물 종류를 알리는 라벨 — 스펙 §6 */
function drawLabelBadge(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  label: PostLabel,
  fontSize: number,
): void {
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
}

/**
 * drawWatermark이 차지하는 우하단 영역의 위쪽 y좌표와 타일 크기. 그리기 자체와, 세로 여유
 * 공간을 계산해야 하는 템플릿(C 터미널·D 질문)이 이 숫자를 공유한다 — 두 곳에서 따로
 * 계산하면 어긋나기 쉽다.
 */
function watermarkBand(W: number, H: number): { top: number; tile: number } {
  const tile = Math.round(W * 0.055)
  const pad = Math.round(W * 0.03)
  return { top: H - pad - tile, tile }
}

/**
 * fitPixelFont의 세로 버전. heightFn(size)가 limit을 넘는 동안 폰트 크기를 8px 단위로
 * 줄인다 — 콘텐츠가 길어져 워터마크나 캔버스 아래쪽을 침범할 때 블록 전체를 위로 밀어
 * 넣는 데 쓴다. fitPixelFont와 같이 8px에서 바닥을 친다.
 */
function fitVertical(size: number, limit: number, heightFn: (size: number) => number): number {
  let fitted = size
  while (fitted > 8 && heightFn(fitted) > limit) {
    fitted = pixelFontSize(fitted - 8)
  }
  return fitted
}

/**
 * drawWatermark이 그릴 워터마크의 왼쪽 시작 x좌표. 이름 글자폭을 실측해야 하므로 ctx가
 * 필요하다 — 워터마크 높이에서 가로로 겹치면 안 되는 콘텐츠(A 풀블리드 제목)가 그리기 전에
 * 이 값을 미리 알아야 하므로 계산을 따로 뽑아 공유한다.
 */
function watermarkStartX(ctx: CanvasRenderingContext2D, W: number, H: number): number {
  const { tile } = watermarkBand(W, H)
  const pad = Math.round(W * 0.03)
  const nameSize = pixelFontSize(W * 0.016)
  ctx.font = `${nameSize}px ${DISPLAY_FONT}`
  const nameW = Math.round(textWidth(ctx, 'PIXELARIOUS', nameSize))
  const totalW = tile + Math.round(tile * 0.3) + nameW
  return W - pad - totalW
}

/** 우하단 출처 표시. 캡처가 퍼져도 계정이 남는다 — 스펙 §6 */
function drawWatermark(ctx: CanvasRenderingContext2D, W: number, H: number): void {
  const { top: y, tile } = watermarkBand(W, H)
  const nameSize = pixelFontSize(W * 0.016)
  const x = watermarkStartX(ctx, W, H)
  drawMarkInto(ctx, x, y, tile, tile)
  ctx.font = `${nameSize}px ${DISPLAY_FONT}`
  ctx.textBaseline = 'middle'
  ctx.fillStyle = BRAND.dim
  ctx.fillText('PIXELARIOUS', x + tile + Math.round(tile * 0.3), y + Math.round(tile / 2))
}

/**
 * 이미지를 잘라내며 대상 사각형(x, y, w, h)을 채운다(cover). 픽셀 보간은 끈다 — 스펙 §8
 * W×H 전체를 채우던 원래 형태는 x=0, y=0, w=W, h=H로 호출하면 그대로 재현된다.
 */
function drawImageCover(
  ctx: CanvasRenderingContext2D,
  img: BrandImage,
  x: number,
  y: number,
  w: number,
  h: number,
): void {
  ctx.imageSmoothingEnabled = false
  const scale = Math.max(w / img.width, h / img.height)
  const dw = Math.round(img.width * scale)
  const dh = Math.round(img.height * scale)
  ctx.drawImage(
    img as unknown as CanvasImageSource,
    x + Math.round((w - dw) / 2),
    y + Math.round((h - dh) / 2),
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
    drawImageCover(ctx, spec.image, 0, 0, W, H)
  } else {
    // 스크린샷이 없을 때의 배경. 단색 사각형은 "빈 자리"로 보이므로
    // 커버 아트와 같은 어법(칠흑 + 디더 성운 + 성긴 별)으로 채운다.
    const unit = unitFor(W, H)
    ctx.fillStyle = BRAND.deep
    ctx.fillRect(0, 0, W, H)
    drawDitherGradient(ctx, W, H, unit, BRAND.surface, (t) =>
      t > 0.55 ? 0 : ((0.55 - t) / 0.55) * 0.6,
    )
    // 아래 40%에는 라벨·제목·워터마크가 앉는다.
    drawStarfield(ctx, W, H, unit, 41, [{ x: 0, y: H * 0.6, w: W, h: H * 0.4 }])
  }

  const pad = Math.round(W * 0.055)
  const labelSize = pixelFontSize(W * 0.022)

  // 제목의 마지막 줄은 기본 크기에서 항상 워터마크 높이와 겹친다 — 실측 기반으로 워터마크
  // 시작 x좌표 왼쪽 폭 안에 맞춘다(drawQuestion과 같은 방식). 워터마크보다 왼쪽에 있으면
  // 캔버스 밖으로 넘치는 것도 함께 막힌다.
  const wmX = watermarkStartX(ctx, W, H)
  const titleAvailWidth = wmX - pad
  let titleSize = pixelFontSize(W * 0.062)
  for (const line of spec.title) {
    titleSize = Math.min(titleSize, fitPixelFont(ctx, DISPLAY_FONT, line, titleSize, titleAvailWidth))
  }
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

function drawCartridge(
  ctx: CanvasRenderingContext2D,
  W: number,
  H: number,
  spec: CartridgePost,
): void {
  ctx.fillStyle = BRAND.deep
  ctx.fillRect(0, 0, W, H)

  const pad = Math.round(W * 0.07)
  const boxW = W - pad * 2
  const boxX = pad
  const border = Math.max(2, Math.round(W * 0.005))

  const noSize = pixelFontSize(W * 0.02)
  const titleSize = pixelFontSize(W * 0.036)
  const subSize = pixelFontSize(W * 0.024)
  const descSize = pixelFontSize(W * 0.026)
  const tagSize = pixelFontSize(W * 0.016)

  const coverW = Math.round(boxW * 0.42)
  const coverH = Math.round((coverW * 42) / 100)
  const stripH = coverH + Math.round(W * 0.06)
  const footH = Math.round(descSize * 2.4 + (spec.tags.length ? tagSize * 3 : 0))
  const boxH = stripH + footH
  const boxY = Math.round((H - boxH) / 2)

  // 흰 프레임 위에 서피스 색 본체 — 사이트 .cart와 같은 구성
  ctx.fillStyle = BRAND.text
  ctx.fillRect(boxX - border, boxY - border, boxW + border * 2, boxH + border * 2)
  ctx.fillStyle = BRAND.surface
  ctx.fillRect(boxX, boxY, boxW, boxH)

  // 슬롯 번호
  const innerPad = Math.round(W * 0.028)
  ctx.font = `${noSize}px ${DISPLAY_FONT}`
  ctx.textBaseline = 'middle'
  ctx.fillStyle = BRAND.dim
  const noText = String(spec.index + 1).padStart(2, '0')
  ctx.fillText(noText, boxX + innerPad, boxY + Math.round(stripH / 2))

  // 커버
  const coverX = boxX + innerPad + Math.round(noSize * 2.6)
  const coverY = boxY + Math.round((stripH - coverH) / 2)
  ctx.fillStyle = BRAND.text
  ctx.fillRect(coverX - border, coverY - border, coverW + border * 2, coverH + border * 2)
  if (spec.cover) {
    drawImageCover(ctx, spec.cover, coverX, coverY, coverW, coverH)
  } else {
    ctx.fillStyle = BRAND.bg
    ctx.fillRect(coverX, coverY, coverW, coverH)
  }

  // 제목 / 부제 — 실측 기반으로 박스 안쪽 오른쪽 경계까지만 쓰도록 줄인다(넘치면 8px 단위로 축소)
  const textX = coverX + coverW + innerPad
  const titleAvailWidth = boxX + boxW - textX
  const hasSub = typeof spec.subtitle === 'string' && spec.subtitle.length > 0
  const titleY = boxY + Math.round(stripH / 2) - (hasSub ? Math.round(subSize * 0.9) : 0)
  fitPixelFont(ctx, DISPLAY_FONT, spec.title, titleSize, titleAvailWidth)
  ctx.fillStyle = BRAND.text
  ctx.fillText(spec.title, textX, titleY)
  if (hasSub) {
    ctx.font = `${subSize}px ${BODY_FONT}`
    ctx.fillStyle = BRAND.dim
    ctx.fillText(spec.subtitle as string, textX, titleY + Math.round(subSize * 1.8))
  }

  // 점선 구분선 아래 설명 + 태그 — 설명도 같은 이유로 박스 안쪽 폭에 맞춰 줄인다
  const footY = boxY + stripH
  ctx.fillStyle = BRAND.dim
  for (let x = boxX + innerPad; x < boxX + boxW - innerPad; x += border * 6) {
    ctx.fillRect(x, footY, border * 3, border)
  }
  const descAvailWidth = boxW - innerPad * 2
  fitPixelFont(ctx, BODY_FONT, spec.description, descSize, descAvailWidth)
  ctx.fillStyle = BRAND.text
  ctx.fillText(spec.description, boxX + innerPad, footY + Math.round(descSize * 1.4))

  if (spec.tags.length) {
    ctx.font = `${tagSize}px ${DISPLAY_FONT}`
    ctx.fillStyle = BRAND.accent2
    let tx = boxX + innerPad
    const ty = footY + Math.round(descSize * 1.4) + Math.round(tagSize * 2.6)
    for (const tag of spec.tags) {
      ctx.fillText(tag, tx, ty)
      tx += Math.round(textWidth(ctx, tag, tagSize)) + Math.round(tagSize * 1.6)
    }
  }

  // 출시 공지 전용 템플릿이므로 라벨은 항상 NEW GAME이다
  drawLabelBadge(ctx, boxX, Math.round(boxY - pad * 0.9), 'NEW GAME', pixelFontSize(W * 0.022))
  drawWatermark(ctx, W, H)
}

function drawTerminal(
  ctx: CanvasRenderingContext2D,
  W: number,
  H: number,
  spec: TerminalPost,
): void {
  ctx.fillStyle = BRAND.deep
  ctx.fillRect(0, 0, W, H)

  const pad = Math.round(W * 0.075)
  const labelSize = pixelFontSize(W * 0.022)
  drawLabelBadge(ctx, pad, pad, spec.label, labelSize)

  // 좌우 여백을 남긴 실사용 폭. 로그 줄과 헤드라인 둘 다 실측 기반으로 이 폭 안에 맞춘다 —
  // 긴 빌드 로그나 긴 헤드라인 문장이 캔버스를 넘치는 사고를 막는다.
  const availWidth = W - pad * 2

  let logSize = pixelFontSize(W * 0.022)
  for (const line of spec.log) {
    const combined = line.text + (line.status ?? '')
    logSize = Math.min(logSize, fitPixelFont(ctx, DISPLAY_FONT, combined, logSize, availWidth))
  }

  let headSize = pixelFontSize(W * 0.062)
  for (const line of spec.headline) {
    headSize = Math.min(headSize, fitPixelFont(ctx, BODY_FONT, line, headSize, availWidth))
  }

  // 세로 여유 공간 — 워터마크 밴드 위, 아래쪽으로 pad만큼 더 여유를 둔다. 개발 로그는
  // 실사용에서 줄 수가 얼마든 늘어날 수 있으므로, 헤드라인 크기는 고정한 채 로그 글자
  // 크기(와 거기서 파생된 줄 간격)만 8px 단위로 줄여 커서가 워터마크나 캔버스 밖으로
  // 밀려나지 않게 한다 — fitPixelFont의 세로 버전.
  const contentTop = pad + Math.round(labelSize * 4.2)
  const bottomLimit = watermarkBand(W, H).top - pad
  const logCount = spec.log.length
  const headCount = spec.headline.length
  logSize = fitVertical(logSize, bottomLimit, (size) => {
    const gap = Math.round(size * 2.4)
    const y = contentTop + gap * logCount + Math.round(headSize * 0.8)
    const headGap = Math.round(headSize * 1.5)
    const lastY = y + headGap * Math.max(0, headCount - 1)
    return lastY + Math.round(headSize / 2)
  })

  const logGap = Math.round(logSize * 2.4)
  let y = contentTop

  ctx.textBaseline = 'middle'
  for (const line of spec.log) {
    ctx.font = `${logSize}px ${DISPLAY_FONT}`
    ctx.fillStyle = BRAND.dim
    ctx.fillText(line.text, pad, y)
    if (line.status) {
      const x = pad + Math.round(textWidth(ctx, line.text, logSize))
      ctx.fillStyle = line.tone === 'gold' ? BRAND.gold : BRAND.accent2
      ctx.fillText(line.status, x, y)
    }
    y += logGap
  }

  const headGap = Math.round(headSize * 1.5)
  y += Math.round(headSize * 0.8)
  ctx.font = `${headSize}px ${BODY_FONT}`
  ctx.fillStyle = BRAND.text
  let lastX = pad
  spec.headline.forEach((line, i) => {
    const lineY = y + headGap * i
    ctx.fillText(line, pad, lineY)
    lastX = pad + Math.round(textWidth(ctx, line, headSize))
  })

  // 마지막 줄 끝에서 커서가 깜빡인다 — 정지 이미지에서는 켜진 상태 (스펙 §4.1)
  const lastY = y + headGap * Math.max(0, spec.headline.length - 1)
  ctx.fillStyle = BRAND.gold
  ctx.fillRect(
    lastX + Math.round(headSize * 0.16),
    Math.round(lastY - headSize / 2),
    Math.round(headSize * 0.62),
    headSize,
  )

  drawWatermark(ctx, W, H)
}

function drawQuestion(
  ctx: CanvasRenderingContext2D,
  W: number,
  H: number,
  spec: QuestionPost,
): void {
  ctx.fillStyle = BRAND.deep
  ctx.fillRect(0, 0, W, H)

  const pad = Math.round(W * 0.075)
  const labelSize = pixelFontSize(W * 0.022)
  drawLabelBadge(ctx, pad, pad, spec.label, labelSize)

  // 배경을 비워 피드에서 눈에 걸리게 한다 — 글자는 크게, 가운데 정렬하지 않고 왼쪽에 쌓는다.
  // 실측 기반으로 좌우 여백 안에 맞춘다 — 긴 질문 한 줄이 캔버스를 넘치는 사고를 막는다.
  const availWidth = W - pad * 2
  let qSize = pixelFontSize(W * 0.085)
  for (const line of spec.question) {
    qSize = Math.min(qSize, fitPixelFont(ctx, BODY_FONT, line, qSize, availWidth))
  }

  // 질문이 길어져 줄 수가 늘면 가운데 정렬된 블록이 커지면서 워터마크와 겹칠 수 있다 —
  // 터미널과 같은 방식으로 글자 크기(와 거기서 파생된 줄 간격)를 8px 단위로 줄여 블록을
  // 워터마크 위로 밀어 넣는다.
  const bottomLimit = watermarkBand(W, H).top - pad
  const qCount = spec.question.length
  qSize = fitVertical(qSize, bottomLimit, (size) => {
    const gap = Math.round(size * 1.45)
    const blockH = gap * qCount
    const firstY = Math.round((H - blockH) / 2 + gap / 2)
    const lastY = firstY + gap * Math.max(0, qCount - 1)
    return lastY + Math.round(size / 2)
  })

  const qGap = Math.round(qSize * 1.45)
  const blockH = qGap * spec.question.length
  const firstY = Math.round((H - blockH) / 2 + qGap / 2)

  ctx.font = `${qSize}px ${BODY_FONT}`
  ctx.textBaseline = 'middle'
  ctx.fillStyle = BRAND.text
  spec.question.forEach((line, i) => {
    ctx.fillText(line, pad, firstY + qGap * i)
  })

  drawWatermark(ctx, W, H)
}

export function drawPost(canvas: BrandCanvas, spec: PostSpec): void {
  const ctx = canvas.getContext('2d')
  if (!ctx) return
  const W = canvas.width
  const H = canvas.height

  if (spec.kind === 'full') drawFullBleed(ctx, W, H, spec)
  else if (spec.kind === 'cartridge') drawCartridge(ctx, W, H, spec)
  else if (spec.kind === 'terminal') drawTerminal(ctx, W, H, spec)
  else drawQuestion(ctx, W, H, spec)

  drawScanlines(ctx, W, H, unitFor(W, H))
}
