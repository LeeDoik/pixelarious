import { describe, it, expect, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { ContinueSlot } from './ContinueSlot'

afterEach(cleanup)

describe('ContinueSlot', () => {
  it('links to the donation address', () => {
    render(<ContinueSlot href="https://toon.at/donate/pixelarious" index={3} />)
    const link = screen.getByRole('link')
    expect(link.getAttribute('href')).toBe('https://toon.at/donate/pixelarious')
  })

  it('opens in a new tab without handing the opener over', () => {
    render(<ContinueSlot href="https://toon.at/donate/pixelarious" index={3} />)
    const link = screen.getByRole('link')
    expect(link.getAttribute('target')).toBe('_blank')
    expect(link.getAttribute('rel')).toContain('noopener')
  })

  it('continues the slot numbering of the lineup', () => {
    render(<ContinueSlot href="https://toon.at/donate/pixelarious" index={3} />)
    expect(screen.getByText('04')).toBeDefined()
  })

  it('draws nothing when no donation address is set, so no dead slot ships', () => {
    const { container } = render(<ContinueSlot index={3} />)
    expect(container.firstChild).toBeNull()
  })
})
