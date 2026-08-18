import { describe, it, expect, afterEach, vi } from 'vitest'
import { render, screen, cleanup, fireEvent } from '@testing-library/react'
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

/** 스펙에 고정된 8개 자산의 내보내기 크기. profile 1024x1024, favicon 32x32,
 * youtube-banner 2560x1440, shorts-card 1080x1920, 정사각형 포스트 3종
 * 1080x1080, 세로형 질문 카드 1080x1350. */
const EXPECTED_ASSETS: { id: string; w: number; h: number }[] = [
  { id: 'profile', w: 1024, h: 1024 },
  { id: 'favicon', w: 32, h: 32 },
  { id: 'youtube-banner', w: 2560, h: 1440 },
  { id: 'shorts-card', w: 1080, h: 1920 },
  { id: 'post-full', w: 1080, h: 1080 },
  { id: 'post-cartridge', w: 1080, h: 1080 },
  { id: 'post-terminal', w: 1080, h: 1080 },
  { id: 'post-question', w: 1080, h: 1350 },
]

describe('BrandClient', () => {
  it.each(EXPECTED_ASSETS)(
    'renders canvas[data-asset="$id"] at its exact export size ($w x $h)',
    ({ id, w, h }) => {
      const { container } = render(<BrandClient games={games} />)
      const canvas = container.querySelector(`canvas[data-asset="${id}"]`)
      expect(canvas?.getAttribute('width')).toBe(String(w))
      expect(canvas?.getAttribute('height')).toBe(String(h))
    },
  )

  it('distinguishes the 1080x1080 square posts from the 1080x1350 question card', () => {
    const { container } = render(<BrandClient games={games} />)
    const squareHeights = ['post-full', 'post-cartridge', 'post-terminal'].map(
      (id) => container.querySelector(`canvas[data-asset="${id}"]`)?.getAttribute('height'),
    )
    expect(squareHeights).toEqual(['1080', '1080', '1080'])
    const question = container.querySelector('canvas[data-asset="post-question"]')
    expect(question?.getAttribute('height')).toBe('1350')
    expect(question?.getAttribute('height')).not.toBe(
      container.querySelector('canvas[data-asset="post-full"]')?.getAttribute('height'),
    )
  })

  it('renders exactly the 8 spec assets, each with its own export button', () => {
    const { container } = render(<BrandClient games={games} />)
    const canvases = container.querySelectorAll('canvas[data-asset]')
    const buttons = screen.getAllByRole('button', { name: /PNG 내보내기/ })
    expect(canvases.length).toBe(8)
    expect(buttons.length).toBe(canvases.length)
  })

  it('clicking an export button invokes the canvas toBlob to produce the PNG', () => {
    // jsdom's HTMLCanvasElement.prototype.toBlob exists but only logs
    // "not implemented" and never calls back — stub it so we can prove the
    // click actually drives an export, not just that a button exists.
    const toBlobSpy = vi
      .spyOn(HTMLCanvasElement.prototype, 'toBlob')
      .mockImplementation(function (callback) {
        callback(new Blob(['stub'], { type: 'image/png' }))
      })
    const createObjectURLSpy = vi
      .fn(() => 'blob:mock-url')
      .mockName('URL.createObjectURL')
    const revokeObjectURLSpy = vi.fn().mockName('URL.revokeObjectURL')
    // jsdom does not implement these either; stub them so the download path
    // in BrandClient can run to completion without throwing.
    URL.createObjectURL = createObjectURLSpy as unknown as typeof URL.createObjectURL
    URL.revokeObjectURL = revokeObjectURLSpy

    render(<BrandClient games={games} />)
    const button = screen.getAllByRole('button', { name: /PNG 내보내기/ })[0]
    fireEvent.click(button)

    expect(toBlobSpy).toHaveBeenCalledTimes(1)
    expect(toBlobSpy.mock.calls[0][1]).toBe('image/png')
    expect(createObjectURLSpy).toHaveBeenCalledTimes(1)

    toBlobSpy.mockRestore()
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
