import { describe, it, expect, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { BrandClient } from './BrandClient'
import type { Game } from '@/lib/games'

afterEach(cleanup)

const games: Game[] = [
  {
    slug: 'starfall-drift',
    order: 10,
    title: 'STARFALL DRIFT',
    description: '탭 한 번으로 궤도를 바꿔 별에서 별로.',
    tags: ['GODOT 4', 'ARCADE'],
    coverScene: 'starfall',
    playPath: null,
  },
]

describe('BrandClient', () => {
  it('renders one canvas per asset at its exact export size', () => {
    const { container } = render(<BrandClient games={games} />)
    const profile = container.querySelector('canvas[data-asset="profile"]')
    expect(profile?.getAttribute('width')).toBe('1024')
    expect(profile?.getAttribute('height')).toBe('1024')
    const banner = container.querySelector('canvas[data-asset="youtube-banner"]')
    expect(banner?.getAttribute('width')).toBe('2560')
    expect(banner?.getAttribute('height')).toBe('1440')
    const favicon = container.querySelector('canvas[data-asset="favicon"]')
    expect(favicon?.getAttribute('width')).toBe('32')
  })

  it('offers a PNG download for every asset', () => {
    const { container } = render(<BrandClient games={games} />)
    const canvases = container.querySelectorAll('canvas[data-asset]')
    const buttons = screen.getAllByRole('button', { name: /PNG 내보내기/ })
    expect(buttons.length).toBe(canvases.length)
  })

  it('lists the four post templates and no others', () => {
    render(<BrandClient games={games} />)
    expect(screen.getByText('A. 풀블리드')).toBeDefined()
    expect(screen.getByText('B. 카트리지')).toBeDefined()
    expect(screen.getByText('C. 터미널 로그')).toBeDefined()
    expect(screen.getByText('D. 질문 카드')).toBeDefined()
  })

  it('survives jsdom where getContext returns null', () => {
    expect(() => render(<BrandClient games={games} />)).not.toThrow()
  })
})
