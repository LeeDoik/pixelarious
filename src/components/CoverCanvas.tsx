'use client'

import { useEffect, useRef } from 'react'
import { drawCoverImage, drawScene, type CoverScene } from '@/lib/scenes'
import { usePalette } from './ThemeProvider'

export function CoverCanvas({ scene, image }: { scene: CoverScene; image?: string }) {
  const ref = useRef<HTMLCanvasElement>(null)
  const { palette } = usePalette()

  useEffect(() => {
    const canvas = ref.current
    if (!canvas) return
    // 절차 생성 씬을 먼저 그린다 — 이미지 로드 전/실패 시의 폴백
    drawScene(canvas, scene, palette)
    if (!image) return
    let cancelled = false
    const img = new Image()
    img.onload = () => {
      if (!cancelled && ref.current) drawCoverImage(ref.current, img, palette)
    }
    img.src = image
    return () => {
      cancelled = true
    }
  }, [scene, image, palette])

  return <canvas ref={ref} className="cover" width={100} height={42} aria-hidden="true" />
}
