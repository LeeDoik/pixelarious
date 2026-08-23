import { describe, it, expect, afterEach, beforeEach, vi } from 'vitest'
import { render, screen, fireEvent, cleanup, act } from '@testing-library/react'
import { PlayFrame, ENGAGED_MS } from './PlayFrame'

const track = vi.fn()
vi.mock('@vercel/analytics', () => ({ track: (...a: unknown[]) => track(...a) }))

beforeEach(() => vi.useFakeTimers())
afterEach(() => {
  vi.useRealTimers()
  cleanup()
  track.mockClear()
})

const props = { slug: 'starfall-drift', title: 'STARFALL DRIFT', playPath: '/games/x/index.html' }

describe('PlayFrame', () => {
  it('셸이 뜨기 전에는 아무것도 보내지 않는다', () => {
    render(<PlayFrame {...props} />)
    expect(track).not.toHaveBeenCalled()
  })

  it('iframe이 뜨면 game_start를 슬러그와 함께 보낸다', () => {
    render(<PlayFrame {...props} />)
    fireEvent.load(screen.getByTitle('STARFALL DRIFT'))
    expect(track).toHaveBeenCalledWith('game_start', {
      slug: 'starfall-drift',
      title: 'STARFALL DRIFT',
    })
  })

  it('15초를 넘겨야 game_engaged가 나간다', () => {
    render(<PlayFrame {...props} />)
    fireEvent.load(screen.getByTitle('STARFALL DRIFT'))
    act(() => void vi.advanceTimersByTime(ENGAGED_MS - 1))
    expect(track).toHaveBeenCalledTimes(1)
    act(() => void vi.advanceTimersByTime(1))
    expect(track).toHaveBeenCalledWith('game_engaged', {
      slug: 'starfall-drift',
      title: 'STARFALL DRIFT',
    })
  })

  it('15초 전에 떠나면 game_engaged가 나가지 않는다', () => {
    const { unmount } = render(<PlayFrame {...props} />)
    fireEvent.load(screen.getByTitle('STARFALL DRIFT'))
    unmount()
    act(() => void vi.advanceTimersByTime(ENGAGED_MS * 2))
    expect(track).toHaveBeenCalledTimes(1)
  })

  it('load가 두 번 와도 game_start는 한 번만 나간다', () => {
    render(<PlayFrame {...props} />)
    const f = screen.getByTitle('STARFALL DRIFT')
    fireEvent.load(f)
    fireEvent.load(f)
    expect(track.mock.calls.filter((c) => c[0] === 'game_start')).toHaveLength(1)
  })
})
