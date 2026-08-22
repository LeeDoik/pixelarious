import { describe, it, expect } from 'vitest'
import { getGames, getGame, getVisibleGames, validate } from './games'

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
    expect(playable.map((g) => g.slug)).toEqual([
      'starfall-drift',
      'it-sleeps-below',
      'last-login',
      'system-check',
    ])
  })

  it('hides flagged cartridges from the public lineup but keeps them in the registry', () => {
    const visible = getVisibleGames().map((g) => g.slug)
    expect(visible).not.toContain('it-sleeps-below')
    expect(visible).not.toContain('pixel-pong-exe')
    expect(visible).not.toContain('system-check')
    expect(getGames().map((g) => g.slug)).toEqual(
      expect.arrayContaining(['it-sleeps-below', 'pixel-pong-exe', 'system-check']),
    )
  })

  it('visible lineup is exactly the expected slugs, still order-sorted', () => {
    expect(getVisibleGames().map((g) => g.slug)).toEqual([
      'starfall-drift',
      'last-login',
    ])
  })

  it('keeps a hidden cartridge reachable by slug so /play still resolves', () => {
    expect(getGame('it-sleeps-below')?.playPath).toBe('/games/it-sleeps-below/index.html')
  })

  it('rejects a non-boolean hidden flag and keeps the field optional', () => {
    expect(() => validate({ ...valid, hidden: 'yes' }, 'x.json')).toThrow()
    expect(() => validate({ ...valid, hidden: true }, 'x.json')).not.toThrow()
    expect(() => validate({ ...valid }, 'x.json')).not.toThrow()
  })

  it('rejects a non-boolean pcRecommended flag and keeps the field optional', () => {
    expect(() => validate({ ...valid, pcRecommended: 'yes' }, 'x.json')).toThrow()
    expect(() => validate({ ...valid, pcRecommended: true }, 'x.json')).not.toThrow()
    expect(() => validate({ ...valid }, 'x.json')).not.toThrow()
  })

  it('last-login is flagged pcRecommended so touch devices get the PC notice', () => {
    expect(getGame('last-login')?.pcRecommended).toBe(true)
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
