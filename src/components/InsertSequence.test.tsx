import { describe, it, expect, afterEach, beforeEach, vi } from 'vitest'
import { render, fireEvent, act, cleanup } from '@testing-library/react'
import { InsertSequence, PHASE_MS } from './InsertSequence'
import type { Game } from '@/lib/games'

const push = vi.fn()
const prefetch = vi.fn()
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push, prefetch }),
}))

const game: Game = {
  slug: 'starfall-drift',
  order: 10,
  title: 'STARFALL DRIFT',
  description: '설명',
  tags: ['GODOT 4'],
  coverScene: 'starfall',
  playPath: '/games/starfall-drift/index.html',
}

const stubReduced = (reduced: boolean) =>
  vi.stubGlobal('matchMedia', (query: string) => ({
    matches: query.includes('prefers-reduced-motion') ? reduced : false,
    media: query,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  }))

const TOTAL =
  PHASE_MS.enter + PHASE_MS.insert + PHASE_MS.clunk + PHASE_MS.power + PHASE_MS.launch

beforeEach(() => {
  vi.useFakeTimers()
})
afterEach(() => {
  vi.useRealTimers()
  cleanup()
  push.mockClear()
  prefetch.mockClear()
  vi.unstubAllGlobals()
})

describe('InsertSequence', () => {
  it('단계를 거친 뒤 /play/<slug>로 넘어간다', () => {
    stubReduced(false)
    const { container } = render(<InsertSequence game={game} />)
    const overlay = container.querySelector('.insert-overlay')!

    expect(overlay.getAttribute('data-phase')).toBe('enter')
    act(() => void vi.advanceTimersByTime(PHASE_MS.enter))
    expect(overlay.getAttribute('data-phase')).toBe('insert')
    act(() => void vi.advanceTimersByTime(PHASE_MS.insert))
    expect(overlay.getAttribute('data-phase')).toBe('clunk')
    act(() => void vi.advanceTimersByTime(PHASE_MS.clunk))
    expect(overlay.getAttribute('data-phase')).toBe('power')
    expect(container.querySelector('.console.lit')).not.toBeNull()
    act(() => void vi.advanceTimersByTime(PHASE_MS.power))
    expect(overlay.getAttribute('data-phase')).toBe('launch')
    // 전원은 launch 동안에도 들어와 있어야 한다 — 꺼졌다 켜지면 깜빡인다
    expect(container.querySelector('.console.lit')).not.toBeNull()

    expect(push).not.toHaveBeenCalled()
    act(() => void vi.advanceTimersByTime(PHASE_MS.launch))
    expect(push).toHaveBeenCalledWith('/play/starfall-drift')
  })

  it('라우트를 미리 받아둔다 (게임 iframe은 미리 띄우지 않는다)', () => {
    stubReduced(false)
    const { container } = render(<InsertSequence game={game} />)
    expect(prefetch).toHaveBeenCalledWith('/play/starfall-drift')
    expect(container.querySelector('iframe')).toBeNull()
  })

  it('모션을 줄이려는 사용자는 애니메이션 없이 바로 이동한다', () => {
    stubReduced(true)
    render(<InsertSequence game={game} />)
    expect(push).toHaveBeenCalledWith('/play/starfall-drift')
  })

  it('클릭으로 건너뛸 수 있고 이동은 한 번만 일어난다', () => {
    stubReduced(false)
    const { container } = render(<InsertSequence game={game} />)
    fireEvent.click(container.querySelector('.insert-overlay')!)
    expect(push).toHaveBeenCalledWith('/play/starfall-drift')
    act(() => void vi.advanceTimersByTime(TOTAL * 2))
    expect(push).toHaveBeenCalledTimes(1)
  })

  it('아무 키나 눌러도 건너뛴다', () => {
    stubReduced(false)
    render(<InsertSequence game={game} />)
    fireEvent.keyDown(window, { key: 'x' })
    expect(push).toHaveBeenCalledWith('/play/starfall-drift')
  })

  it('부팅 로그에 게임 제목이 뜬다', () => {
    stubReduced(false)
    const { container } = render(<InsertSequence game={game} />)
    const log = container.querySelector('.boot-log')!.textContent ?? ''
    expect(log).toContain('CARTRIDGE DETECTED')
    expect(log).toContain('STARFALL DRIFT')
  })
})
