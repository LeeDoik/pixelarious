'use client'

import { createContext, useContext, useEffect, useState } from 'react'
import type { Palette } from '@/lib/scenes'

const ThemeContext = createContext<{ palette: Palette; toggle: () => void }>({
  palette: 'night',
  toggle: () => {},
})

function readSaved(): Palette {
  if (typeof window === 'undefined') return 'night'
  try {
    return localStorage.getItem('palette') === 'dmg' ? 'dmg' : 'night'
  } catch {
    return 'night'
  }
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [palette, setPalette] = useState<Palette>('night')
  const [restored, setRestored] = useState(false)

  useEffect(() => {
    setPalette(readSaved())
    setRestored(true)
  }, [])

  useEffect(() => {
    // Hydrate the server's palette first, then persist the saved client choice.
    if (!restored) return
    document.body.classList.toggle('dmg', palette === 'dmg')
    try {
      localStorage.setItem('palette', palette)
    } catch {}
  }, [palette, restored])

  const toggle = () => setPalette((p) => (p === 'night' ? 'dmg' : 'night'))

  return <ThemeContext.Provider value={{ palette, toggle }}>{children}</ThemeContext.Provider>
}

export function usePalette() {
  return useContext(ThemeContext)
}
