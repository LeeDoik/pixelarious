'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  drawProfile,
  drawFavicon,
  drawYouTubeBanner,
  drawShortsCard,
  drawPost,
  type PostSpec,
} from '@/lib/brand'
import { drawScene } from '@/lib/scenes'
import type { Game } from '@/lib/games'
import styles from './BrandClient.module.css'

interface AssetDef {
  id: string
  name: string
  w: number
  h: number
  draw: (canvas: HTMLCanvasElement) => void
}

/** 미리보기 표시 폭. 내보내기는 항상 원본 크기다. */
const PREVIEW_MAX = 320

/** 훅이 아니다 — useMemo로 감싸 렌더마다 자산이 새로 만들어지지 않게 한다. */
function buildAssets(games: Game[]): AssetDef[] {
  const first = games[0]

  /** 카트리지 커버를 사이트와 같은 100×42로 미리 그려 넘긴다. */
  const renderCover = (): HTMLCanvasElement | null => {
    if (typeof document === 'undefined' || !first) return null
    const c = document.createElement('canvas')
    c.width = 100
    c.height = 42
    if (!c.getContext('2d')) return null
    drawScene(c, first.coverScene, 'night')
    return c
  }

  const samplePosts: { id: string; name: string; w: number; h: number; spec: PostSpec }[] = [
    {
      id: 'post-full',
      name: 'A. 풀블리드',
      w: 1080,
      h: 1080,
      spec: {
        kind: 'full',
        label: 'NEW GAME',
        title: first ? first.title.split(' ') : ['NEW', 'GAME'],
        image: null,
      },
    },
    {
      id: 'post-cartridge',
      name: 'B. 카트리지',
      w: 1080,
      h: 1080,
      spec: {
        kind: 'cartridge',
        index: 0,
        title: first?.title ?? 'TITLE',
        subtitle: first?.subtitle,
        description: first?.description.split('\n')[0] ?? '',
        tags: first?.tags ?? [],
        cover: null,
      },
    },
    {
      id: 'post-terminal',
      name: 'C. 터미널 로그',
      w: 1080,
      h: 1080,
      spec: {
        kind: 'terminal',
        label: 'DEV LOG',
        log: [
          { text: '> BUILD v0.3.1', status: ' ... OK', tone: 'ok' },
          { text: '> LAMP RADIUS 8 -> 5', status: ' ... CHANGED', tone: 'gold' },
        ],
        headline: ['동굴이 훨씬', '무서워졌습니다'],
      },
    },
    {
      id: 'post-question',
      name: 'D. 질문 카드',
      w: 1080,
      h: 1350,
      spec: {
        kind: 'question',
        label: 'YOUR TURN',
        question: ['다음 게임,', '어떤 걸', '보고 싶으세요?'],
      },
    },
  ]

  return [
    { id: 'profile', name: '프로필 (3채널 공통)', w: 1024, h: 1024, draw: (c) => drawProfile(c) },
    { id: 'favicon', name: '파비콘', w: 32, h: 32, draw: (c) => drawFavicon(c) },
    {
      id: 'youtube-banner',
      name: '유튜브 배너',
      w: 2560,
      h: 1440,
      draw: (c) => drawYouTubeBanner(c),
    },
    {
      id: 'shorts-card',
      name: '쇼츠 카드',
      w: 1080,
      h: 1920,
      draw: (c) => drawShortsCard(c, ['새 게임이', '나왔습니다']),
    },
    ...samplePosts.map((p) => ({
      id: p.id,
      name: p.name,
      w: p.w,
      h: p.h,
      draw: (c: HTMLCanvasElement) => {
        const spec =
          p.spec.kind === 'cartridge' ? { ...p.spec, cover: renderCover() } : p.spec
        drawPost(c, spec)
      },
    })),
  ]
}

function AssetCard({ asset }: { asset: AssetDef }) {
  const ref = useRef<HTMLCanvasElement>(null)
  const [ready, setReady] = useState(false)

  useEffect(() => {
    let cancelled = false
    const paint = () => {
      if (cancelled || !ref.current) return
      asset.draw(ref.current)
      setReady(true)
    }
    // 픽셀 폰트가 로드되기 전에 그리면 대체 폰트로 렌더된다
    const fonts = (document as Document & { fonts?: FontFaceSet }).fonts
    if (fonts?.load) {
      Promise.all([fonts.load('16px PS2P'), fonts.load('16px NeoDGM')]).then(paint, paint)
    } else {
      paint()
    }
    return () => {
      cancelled = true
    }
  }, [asset])

  const download = useCallback(() => {
    const canvas = ref.current
    if (!canvas || typeof canvas.toBlob !== 'function') return
    canvas.toBlob((blob) => {
      if (!blob) return
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `pixelarious-${asset.id}-${asset.w}x${asset.h}.png`
      a.click()
      URL.revokeObjectURL(url)
    }, 'image/png')
  }, [asset])

  const scale = Math.min(1, PREVIEW_MAX / asset.w)

  return (
    <div className={styles.item}>
      <div className={styles.itemHead}>
        <span className={styles.name}>{asset.name}</span>
        <span className={styles.size}>
          {asset.w} × {asset.h}
        </span>
        <button type="button" className={styles.btn} onClick={download} disabled={!ready}>
          PNG 내보내기
        </button>
      </div>
      <div className={styles.preview}>
        <canvas
          ref={ref}
          data-asset={asset.id}
          width={asset.w}
          height={asset.h}
          style={{ width: `${Math.round(asset.w * scale)}px` }}
        />
      </div>
    </div>
  )
}

export function BrandClient({ games }: { games: Game[] }) {
  const assets = useMemo(() => buildAssets(games), [games])
  return (
    <main className={styles.wrap}>
      <h1 className={styles.head}>BRAND ASSETS</h1>
      <p className={styles.sub}>
        스펙 <code>2026-08-16-pixelarious-brand-design.md</code> 기준으로 렌더합니다. 내보낸 PNG는
        저장소에 커밋하지 않습니다.
      </p>
      <div className={styles.group}>
        <h2 className={styles.groupHead}>▍ 계정 자산</h2>
        {assets.slice(0, 4).map((a) => (
          <AssetCard key={a.id} asset={a} />
        ))}
      </div>
      <div className={styles.group}>
        <h2 className={styles.groupHead}>▍ 포스트 템플릿</h2>
        {assets.slice(4).map((a) => (
          <AssetCard key={a.id} asset={a} />
        ))}
      </div>
    </main>
  )
}
