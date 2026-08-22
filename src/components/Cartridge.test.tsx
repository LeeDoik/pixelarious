import { describe, it, expect, afterEach, vi } from 'vitest'
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

  it('starts open when defaultOpen is set (editor preview)', () => {
    render(<Cartridge game={base} index={0} defaultOpen />)
    expect(screen.getByRole('button').getAttribute('aria-expanded')).toBe('true')
  })

  it('toggles with the keyboard (Enter)', () => {
    render(<Cartridge game={base} index={0} />)
    const strip = screen.getByRole('button')
    fireEvent.keyDown(strip, { key: 'Enter' })
    expect(strip.getAttribute('aria-expanded')).toBe('true')
  })

  it('toggles with the keyboard (Space)', () => {
    render(<Cartridge game={base} index={0} />)
    const strip = screen.getByRole('button')
    fireEvent.keyDown(strip, { key: ' ' })
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

describe('PC-recommended notice', () => {
  const playable: Game = {
    ...base,
    slug: 'last-login',
    playPath: '/games/last-login/index.html',
    pcRecommended: true,
  }

  const stubPointer = (coarse: boolean) =>
    vi.stubGlobal('matchMedia', (query: string) => ({ matches: coarse, media: query }))
  const swallowNav = (e: Event) => e.preventDefault()

  afterEach(() => {
    vi.unstubAllGlobals()
    window.removeEventListener('click', swallowNav)
  })

  it('intercepts PLAY on a coarse-pointer device and shows the notice', () => {
    stubPointer(true)
    render(<Cartridge game={playable} index={0} />)
    fireEvent.click(screen.getByText('▶ PLAY'))
    expect(screen.getByRole('dialog')).toBeDefined()
    expect(screen.getByText(/PC 환경에서 플레이/)).toBeDefined()
    const anyway = screen.getByText('▶ 그래도 플레이').closest('a')
    expect(anyway?.getAttribute('href')).toBe('/play/last-login')
  })

  it('돌아가기 closes the notice', () => {
    stubPointer(true)
    render(<Cartridge game={playable} index={0} />)
    fireEvent.click(screen.getByText('▶ PLAY'))
    fireEvent.click(screen.getByText('돌아가기'))
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('Escape closes the notice', () => {
    stubPointer(true)
    render(<Cartridge game={playable} index={0} />)
    fireEvent.click(screen.getByText('▶ PLAY'))
    fireEvent.keyDown(window, { key: 'Escape' })
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('lets PLAY through untouched on a fine-pointer device', () => {
    stubPointer(false)
    window.addEventListener('click', swallowNav)
    render(<Cartridge game={playable} index={0} />)
    fireEvent.click(screen.getByText('▶ PLAY'))
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('never intercepts games without the flag, even on touch', () => {
    stubPointer(true)
    window.addEventListener('click', swallowNav)
    render(
      <Cartridge game={{ ...base, slug: 'starfall-drift', playPath: '/games/starfall-drift/index.html' }} index={0} />,
    )
    fireEvent.click(screen.getByText('▶ PLAY'))
    expect(screen.queryByRole('dialog')).toBeNull()
  })
})
