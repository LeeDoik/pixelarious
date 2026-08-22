'use client'

import { useEffect, useRef } from 'react'
import { drawCoin, COIN_SIZE } from '@/lib/coin'
import { usePalette } from './ThemeProvider'

/** 16x16 픽셀 토큰. 커버 아트와 같은 방식으로 그리고 정수배로 확대한다. */
export function CoinFace() {
  const ref = useRef<HTMLCanvasElement>(null)
  const { palette } = usePalette()

  useEffect(() => {
    if (ref.current) drawCoin(ref.current, palette)
  }, [palette])

  return (
    <canvas
      ref={ref}
      className="coin-canvas"
      width={COIN_SIZE}
      height={COIN_SIZE}
      aria-hidden="true"
    />
  )
}
