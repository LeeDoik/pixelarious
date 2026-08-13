import { describe, it, expect } from 'vitest'
import { getGames, getGame } from './games'

describe('games registry', () => {
  it('loads all game records without validation errors', () => {
    expect(getGames().length).toBeGreaterThanOrEqual(4)
  })

  it('returns games sorted by order ascending', () => {
    const orders = getGames().map((g) => g.order)
    expect(orders).toEqual([...orders].sort((a, b) => a - b))
  })

  it('has unique slugs', () => {
    const slugs = getGames().map((g) => g.slug)
    expect(new Set(slugs).size).toBe(slugs.length)
  })

  it('system-check cartridge is playable', () => {
    const g = getGame('system-check')
    expect(g?.playPath).toBe('/games/system-check/index.html')
  })

  it('returns undefined for unknown slug', () => {
    expect(getGame('no-such-game')).toBeUndefined()
  })
})
