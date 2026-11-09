import { describe, it, expect, afterEach, vi } from 'vitest'
import { render, screen, fireEvent, cleanup, waitFor, act } from '@testing-library/react'
import { ThemeProvider, usePalette } from './ThemeProvider'
import { PaletteSwap } from './PaletteSwap'
import { renderToString } from 'react-dom/server'
import { hydrateRoot, type Root } from 'react-dom/client'

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

  it('restores saved colors after hydration without leaving server attributes behind', async () => {
    function PaletteMarkup() {
      const { palette } = usePalette()
      return <output data-palette={palette}>{palette}</output>
    }
    const app = <ThemeProvider><PaletteMarkup /></ThemeProvider>
    const host = document.createElement('div')
    host.innerHTML = renderToString(app)
    document.body.appendChild(host)
    localStorage.setItem('palette', 'dmg')
    const errors = vi.spyOn(console, 'error').mockImplementation(() => {})
    const recoverable = vi.fn()
    let root: Root | undefined
    try {
      await act(async () => { root = hydrateRoot(host, app, { onRecoverableError: recoverable }) })
      expect(host.querySelector('output')?.dataset.palette).toBe('dmg')
      expect(document.body.classList.contains('dmg')).toBe(true)
      expect(localStorage.getItem('palette')).toBe('dmg')
      expect(errors).not.toHaveBeenCalled()
      expect(recoverable).not.toHaveBeenCalled()
    } finally {
      act(() => root?.unmount())
      host.remove()
      errors.mockRestore()
    }
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
