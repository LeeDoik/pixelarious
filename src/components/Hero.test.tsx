import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, act, cleanup } from '@testing-library/react'
import { Hero } from './Hero'

afterEach(() => {
  cleanup()
  vi.useRealTimers()
})

describe('Hero', () => {
  it('types out NEO_KIDO over time', () => {
    vi.useFakeTimers()
    render(<Hero />)
    const h1 = screen.getByRole('heading', { level: 1 })
    expect(h1.textContent).not.toContain('NEO_KIDO')
    act(() => {
      vi.advanceTimersByTime(600 + 95 * 8 + 300)
    })
    expect(h1.textContent).toContain('NEO_KIDO')
  })

  it('shows the full name immediately when reduced motion is preferred', () => {
    vi.mocked(window.matchMedia).mockReturnValueOnce({
      matches: true,
      media: '(prefers-reduced-motion: reduce)',
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    } as unknown as MediaQueryList)
    render(<Hero />)
    expect(screen.getByRole('heading', { level: 1 }).textContent).toContain('NEO_KIDO')
  })
})
