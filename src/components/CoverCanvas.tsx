'use client'

import { useEffect, useRef } from 'react'
import { drawScene, type CoverScene } from '@/lib/scenes'
import { usePalette } from './ThemeProvider'

export function CoverCanvas({ scene }: { scene: CoverScene }) {
  const ref = useRef<HTMLCanvasElement>(null)
  const { palette } = usePalette()

  useEffect(() => {
    if (ref.current) drawScene(ref.current, scene, palette)
  }, [scene, palette])

  return <canvas ref={ref} className="cover" width={100} height={42} aria-hidden="true" />
}
