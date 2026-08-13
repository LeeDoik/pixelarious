import { describe, it, expect, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup } from '@testing-library/react'
import { ThemeProvider } from './ThemeProvider'
import { PaletteSwap } from './PaletteSwap'

afterEach(() => {
  cleanup()
  document.body.classList.remove('dmg')
  localStorage.clear()
})

describe('theme system', () => {
  it('toggles the dmg body class and persists the choice', () => {
    render(
      <ThemeProvider>
        <PaletteSwap />
      </ThemeProvider>,
    )
    const btn = screen.getByRole('button', { name: /PALETTE/ })
    fireEvent.click(btn)
    expect(document.body.classList.contains('dmg')).toBe(true)
    expect(localStorage.getItem('palette')).toBe('dmg')
    fireEvent.click(btn)
    expect(document.body.classList.contains('dmg')).toBe(false)
    expect(localStorage.getItem('palette')).toBe('night')
  })

  it('restores a saved dmg palette on mount', () => {
    localStorage.setItem('palette', 'dmg')
    render(
      <ThemeProvider>
        <PaletteSwap />
      </ThemeProvider>,
    )
    expect(document.body.classList.contains('dmg')).toBe(true)
  })
})
