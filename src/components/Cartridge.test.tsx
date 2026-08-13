import { describe, it, expect, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup } from '@testing-library/react'
import { Cartridge } from './Cartridge'
import type { Game } from '@/lib/games'

afterEach(cleanup)

const base: Game = {
  slug: 'starfall-drift',
  order: 10,
  title: 'STARFALL DRIFT',
  description: '중력을 뒤집으며 별 사이를 활강하는 우주 플랫포머.',
  tags: ['GODOT 4', '2D'],
  coverScene: 'starfall',
  playPath: null,
}

describe('Cartridge', () => {
  it('toggles open state on click with aria-expanded', () => {
    render(<Cartridge game={base} index={0} />)
    const strip = screen.getByRole('button')
    expect(strip.getAttribute('aria-expanded')).toBe('false')
    fireEvent.click(strip)
    expect(strip.getAttribute('aria-expanded')).toBe('true')
    fireEvent.click(strip)
    expect(strip.getAttribute('aria-expanded')).toBe('false')
  })

  it('toggles with the keyboard (Enter)', () => {
    render(<Cartridge game={base} index={0} />)
    const strip = screen.getByRole('button')
    fireEvent.keyDown(strip, { key: 'Enter' })
    expect(strip.getAttribute('aria-expanded')).toBe('true')
  })

  it('shows NOT INSERTED instead of a dead link when playPath is null', () => {
    render(<Cartridge game={base} index={0} />)
    expect(screen.getByText('NOT INSERTED')).toBeDefined()
    expect(screen.queryByText('▶ PLAY')).toBeNull()
  })

  it('links PLAY to /play/<slug> when playPath exists', () => {
    render(
      <Cartridge game={{ ...base, slug: 'system-check', playPath: '/games/system-check/index.html' }} index={3} />,
    )
    const play = screen.getByText('▶ PLAY').closest('a')
    expect(play?.getAttribute('href')).toBe('/play/system-check')
  })

  it('renders the 1-based zero-padded slot number', () => {
    render(<Cartridge game={base} index={0} />)
    expect(screen.getByText('01')).toBeDefined()
  })
})
