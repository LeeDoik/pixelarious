import { describe, it, expect, vi } from 'vitest'

vi.mock('next/navigation', () => ({
  notFound: () => {
    throw new Error('NEXT_NOT_FOUND')
  },
}))

vi.mock('@/lib/games', () => ({ getVisibleGames: () => [] }))

describe('/brand page', () => {
  it('404s outside development so the tool never ships (NODE_ENV=test here)', async () => {
    const { default: BrandPage } = await import('./page')
    expect(() => BrandPage()).toThrow('NEXT_NOT_FOUND')
  })
})
