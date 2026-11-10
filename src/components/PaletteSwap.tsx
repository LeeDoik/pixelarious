'use client'

import { useEffect, useState } from 'react'
import { usePalette } from './ThemeProvider'

export function PaletteSwap({ compact = false }: { compact?: boolean }) {
  const { palette, toggle } = usePalette()
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])
  // SSR은 항상 NIGHT로 그리므로, 마운트 전에는 라벨을 NIGHT로 고정해 hydration mismatch를 막는다
  const label = mounted && palette === 'dmg' ? 'DMG' : 'NIGHT'
  return (
    <button className={compact ? 'swap swap-inline' : 'swap'} type="button" onClick={toggle} aria-label={`PALETTE: ${label} ▸ SWAP`}>
      {compact ? <span className="palette-light" aria-hidden="true" /> : 'PALETTE: '}
      <span className="lab">{label}</span> {compact ? '↔' : '▸ SWAP'}
    </button>
  )
}
