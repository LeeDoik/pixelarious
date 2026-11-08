import { describe, it, expect, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react'
import { ThemeProvider, usePalette } from './ThemeProvider'
import { PaletteSwap } from './PaletteSwap'

let captured: { palette: string; toggle: () => void } | null = null

function PaletteProbe() {
  captured = usePalette()
  return null
}

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

  it('restores a saved dmg palette on mount', async () => {
    localStorage.setItem('palette', 'dmg')
    render(
      <ThemeProvider>
        <PaletteSwap />
      </ThemeProvider>,
    )
    expect(document.body.classList.contains('dmg')).toBe(true)
    await waitFor(() => {
      expect(screen.getByRole('button', { name: /PALETTE/ }).textContent).toContain('DMG')
    })
  })

  it('usePalette used outside a provider falls back to the default context', () => {
    captured = null
    render(<PaletteProbe />)
    // React fills the probe during render; TypeScript cannot see that assignment.
    const value = captured as ReturnType<typeof usePalette> | null
    expect(value?.palette).toBe('night')
    expect(typeof value?.toggle).toBe('function')
    expect(() => value?.toggle()).not.toThrow()
  })
})
