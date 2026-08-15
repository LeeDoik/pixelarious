import { describe, it, expect } from 'vitest'
import { getGames, getGame, validate } from './games'

const valid = {
  slug: 'system-check',
  order: 90,
  title: 'SYSTEM CHECK',
  subtitle: '동작 확인용 카트리지',
  description: 'PIXELARIOUS 배포 파이프라인이 정상 작동하는지 확인하는 진단 카트리지입니다.',
  tags: ['SYSTEM', 'WEB'],
  coverScene: 'system',
  playPath: null,
}

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

  it('playable set is exactly the expected slugs', () => {
    const playable = getGames().filter((g) => g.playPath !== null)
    expect(playable.map((g) => g.slug)).toEqual(['starfall-drift', 'last-login', 'system-check'])
  })

  it('rejects a slug with a double hyphen', () => {
    expect(() => validate({ ...valid, slug: 'a--b' }, 'x.json')).toThrow()
  })

  it('rejects a slug with a leading hyphen', () => {
    expect(() => validate({ ...valid, slug: '-abc' }, 'x.json')).toThrow()
  })

  it('rejects a playPath pointing at a missing file', () => {
    expect(() => validate({ ...valid, playPath: '/games/nope/index.html' }, 'x.json')).toThrow()
  })

  it('accepts an existing coverImage and keeps it optional', () => {
    expect(() => validate({ ...valid, coverImage: '/covers/starfall-drift.png' }, 'x.json')).not.toThrow()
    expect(() => validate({ ...valid }, 'x.json')).not.toThrow()
  })

  it('rejects a coverImage pointing at a missing file', () => {
    expect(() => validate({ ...valid, coverImage: '/covers/nope.png' }, 'x.json')).toThrow()
  })
})
