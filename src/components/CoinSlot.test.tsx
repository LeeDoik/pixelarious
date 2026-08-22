import { describe, it, expect, afterEach, beforeEach, vi } from 'vitest'
import { render, screen, fireEvent, act, cleanup } from '@testing-library/react'
import { CoinSlot } from './CoinSlot'

const HREF = 'https://toon.at/donate/pixelarious'

/** 슬릿은 화면 왼쪽 위, 동전은 그 아래 — jsdom엔 레이아웃이 없어 직접 심는다 */
const SLIT = { left: 100, top: 100, right: 113, bottom: 182, width: 13, height: 82 }
const COIN = { left: 100, top: 300, right: 138, bottom: 338, width: 38, height: 38 }

const rect = (b: typeof SLIT) => ({ ...b, x: b.left, y: b.top, toJSON: () => '' }) as DOMRect

const stubLayout = (container: HTMLElement) => {
  vi.spyOn(container.querySelector('.acceptor-slit')!, 'getBoundingClientRect').mockReturnValue(
    rect(SLIT),
  )
  vi.spyOn(screen.getByRole('link'), 'getBoundingClientRect').mockReturnValue(rect(COIN))
}

/** jsdom엔 PointerEvent가 없다 — 좌표가 실리는 MouseEvent에 타입만 씌운다 */
const pointer = (el: Element, type: string, clientX: number, clientY: number) =>
  fireEvent(el, new MouseEvent(type, { clientX, clientY, bubbles: true }))

const openSpy = vi.fn()

beforeEach(() => {
  vi.useFakeTimers()
  // setPointerCapture는 jsdom에 없다
  Element.prototype.setPointerCapture = vi.fn()
  openSpy.mockReturnValue({} as Window)
  vi.stubGlobal('open', openSpy)
})
afterEach(() => {
  vi.useRealTimers()
  cleanup()
  vi.restoreAllMocks()
  vi.unstubAllGlobals()
  openSpy.mockClear()
})

const drag = (el: Element, to: { x: number; y: number }) => {
  pointer(el, 'pointerdown', COIN.left + 19, COIN.top + 19)
  pointer(el, 'pointermove', to.x, to.y)
  pointer(el, 'pointerup', to.x, to.y)
}

describe('CoinSlot', () => {
  it('후원 주소가 없으면 아무것도 그리지 않는다', () => {
    const { container } = render(<CoinSlot />)
    expect(container.firstChild).toBeNull()
  })

  it('동전은 후원 주소로 가는 앵커다 — 눌러도, 키보드로도 열린다', () => {
    render(<CoinSlot href={HREF} />)
    const coin = screen.getByRole('link')
    expect(coin.getAttribute('href')).toBe(HREF)
    expect(coin.getAttribute('target')).toBe('_blank')
    expect(coin.getAttribute('rel')).toContain('noopener')
  })

  it('동전이 왼쪽, 투입구가 오른쪽 — 끄는 방향이 뒤집히지 않게', () => {
    const { container } = render(<CoinSlot href={HREF} />)
    const kids = [...container.querySelector('.coin-acceptor')!.children].map((e) => e.className)
    expect(kids).toEqual(['acceptor-tray', 'acceptor-face'])
  })

  it('억셉터에 INSERT COIN 안내가 박혀 있다', () => {
    render(<CoinSlot href={HREF} />)
    expect(screen.getByText('INSERT COIN')).toBeDefined()
    expect(screen.getByText('1 PLAY')).toBeDefined()
    expect(screen.getByText('DRAG TO INSERT')).toBeDefined()
  })

  it('슬릿에 끌어다 놓으면 크레딧이 오르고 후원 페이지가 열린다', () => {
    const { container } = render(<CoinSlot href={HREF} />)
    stubLayout(container)
    drag(screen.getByRole('link'), { x: SLIT.left + 6, y: SLIT.top + 40 })

    expect(openSpy).toHaveBeenCalledWith(HREF, '_blank', 'noopener,noreferrer')
    expect(screen.getByText('01')).toBeDefined()
    expect(container.querySelector('.coin-acceptor.taken')).not.toBeNull()
  })

  it('빗나가면 아무 일도 없고 동전은 제자리로 돌아온다', () => {
    const { container } = render(<CoinSlot href={HREF} />)
    stubLayout(container)
    drag(screen.getByRole('link'), { x: 600, y: 600 })

    expect(openSpy).not.toHaveBeenCalled()
    expect(screen.getByText('00')).toBeDefined()
    expect(screen.getByRole('link').getAttribute('style')).toContain('translate(0px, 0px)')
  })

  it('먹힌 뒤에는 다음 동전이 다시 대기한다', () => {
    const { container } = render(<CoinSlot href={HREF} />)
    stubLayout(container)
    drag(screen.getByRole('link'), { x: SLIT.left + 6, y: SLIT.top + 40 })
    act(() => void vi.advanceTimersByTime(600))
    expect(container.querySelector('.coin-acceptor.taken')).toBeNull()
    expect(screen.getByRole('link').getAttribute('style')).toContain('translate(0px, 0px)')
  })

  it('끌지 않고 눌렀다 떼면 앵커에 맡긴다 — 직접 열지 않는다', () => {
    const { container } = render(<CoinSlot href={HREF} />)
    stubLayout(container)
    const coin = screen.getByRole('link')
    pointer(coin, 'pointerdown', COIN.left + 19, COIN.top + 19)
    pointer(coin, 'pointerup', COIN.left + 20, COIN.top + 20)
    expect(openSpy).not.toHaveBeenCalled()
  })

  it('팝업이 막혀도 현재 페이지는 그대로 둔다 — 후원은 새 창에서만 연다', () => {
    openSpy.mockReturnValue(null)
    const { container } = render(<CoinSlot href={HREF} />)
    stubLayout(container)
    const before = window.location.href
    drag(screen.getByRole('link'), { x: SLIT.left + 6, y: SLIT.top + 40 })

    expect(window.location.href).toBe(before)
    expect(screen.getByText(/팝업이 막혔습니다/)).toBeDefined()
  })

  it('팝업이 열리면 안내는 뜨지 않는다', () => {
    const { container } = render(<CoinSlot href={HREF} />)
    stubLayout(container)
    drag(screen.getByRole('link'), { x: SLIT.left + 6, y: SLIT.top + 40 })
    expect(screen.queryByText(/팝업이 막혔습니다/)).toBeNull()
  })
})
