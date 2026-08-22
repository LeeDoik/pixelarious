import { describe, it, expect, afterEach, vi } from 'vitest'
import { render, screen, fireEvent, cleanup } from '@testing-library/react'
import { Shelf } from './Shelf'
import type { Game } from '@/lib/games'

const push = vi.fn()
const prefetch = vi.fn()
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push, prefetch }),
}))

afterEach(() => {
  cleanup()
  push.mockClear()
  prefetch.mockClear()
  vi.unstubAllGlobals()
})

const base: Game = {
  slug: 'starfall-drift',
  order: 10,
  title: 'STARFALL DRIFT',
  description: '중력을 뒤집으며 별 사이를 활강하는 우주 플랫포머.',
  tags: ['GODOT 4', '2D'],
  coverScene: 'starfall',
  playPath: '/games/starfall-drift/index.html',
}
const notInserted: Game = { ...base, slug: 'soon', title: 'SOON', playPath: null }

/** matchMedia 스텁 — 포인터 종류와 모션 선호를 질의별로 갈라 답한다. */
const stubMedia = (opts: { coarse?: boolean; reduced?: boolean } = {}) =>
  vi.stubGlobal('matchMedia', (query: string) => ({
    matches: query.includes('pointer: coarse')
      ? !!opts.coarse
      : query.includes('prefers-reduced-motion')
        ? !!opts.reduced
        : false,
    media: query,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  }))

const openPopup = (title: string) =>
  fireEvent.click(screen.getByRole('button', { name: new RegExp(title) }))

describe('Shelf — 진열장', () => {
  it('게임마다 카트리지 타일을 놓고 마지막에 빈 슬롯을 둔다', () => {
    render(<Shelf games={[base, notInserted]} />)
    expect(screen.getByRole('button', { name: /STARFALL DRIFT/ })).toBeDefined()
    expect(screen.getByText('EMPTY SLOT')).toBeDefined()
    expect(screen.getByText('03')).toBeDefined() // 빈 슬롯은 게임 수 + 1번
  })

  it('타일을 누르면 패키지 팝업이 뜨고 상세가 보인다', () => {
    render(<Shelf games={[base]} />)
    expect(screen.queryByRole('dialog')).toBeNull()
    openPopup('STARFALL DRIFT')
    const dialog = screen.getByRole('dialog')
    expect(dialog).toBeDefined()
    expect(screen.getByText(base.description)).toBeDefined()
    expect(screen.getByText('GODOT 4')).toBeDefined()
  })

  it('닫기 버튼과 Escape로 팝업이 닫힌다', () => {
    render(<Shelf games={[base]} />)
    openPopup('STARFALL DRIFT')
    fireEvent.click(screen.getByLabelText('닫기'))
    expect(screen.queryByRole('dialog')).toBeNull()

    openPopup('STARFALL DRIFT')
    fireEvent.keyDown(window, { key: 'Escape' })
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('playPath가 없으면 죽은 링크 대신 NOT INSERTED를 보여준다', () => {
    render(<Shelf games={[notInserted]} />)
    openPopup('SOON')
    expect(screen.getByText('NOT INSERTED')).toBeDefined()
    expect(screen.queryByText('▶ PLAY')).toBeNull()
  })

  it('PLAY를 누르면 삽입 시퀀스가 팝업을 대체한다', () => {
    stubMedia()
    render(<Shelf games={[base]} />)
    openPopup('STARFALL DRIFT')
    fireEvent.click(screen.getByText('▶ PLAY'))
    expect(screen.queryByText(base.description)).toBeNull()
    expect(screen.getByLabelText(/카트리지를 삽입하는 중/)).toBeDefined()
  })
})

describe('Shelf — PC 권장 안내', () => {
  const playable: Game = { ...base, slug: 'last-login', title: 'LAST LOGIN', pcRecommended: true }

  it('터치 기기에서 PLAY를 가로채 안내를 띄운다', () => {
    stubMedia({ coarse: true })
    render(<Shelf games={[playable]} />)
    openPopup('LAST LOGIN')
    fireEvent.click(screen.getByText('▶ PLAY'))
    expect(screen.getByText(/PC 환경에서 플레이/)).toBeDefined()
    expect(screen.queryByLabelText(/카트리지를 삽입하는 중/)).toBeNull()
  })

  it('돌아가기는 안내만 닫고 팝업은 남긴다', () => {
    stubMedia({ coarse: true })
    render(<Shelf games={[playable]} />)
    openPopup('LAST LOGIN')
    fireEvent.click(screen.getByText('▶ PLAY'))
    fireEvent.click(screen.getByText('돌아가기'))
    expect(screen.queryByText(/PC 환경에서 플레이/)).toBeNull()
    expect(screen.getByText(base.description)).toBeDefined()
  })

  it('그래도 플레이를 누르면 삽입 시퀀스로 넘어간다', () => {
    stubMedia({ coarse: true })
    render(<Shelf games={[playable]} />)
    openPopup('LAST LOGIN')
    fireEvent.click(screen.getByText('▶ PLAY'))
    fireEvent.click(screen.getByText('▶ 그래도 플레이'))
    expect(screen.getByLabelText(/카트리지를 삽입하는 중/)).toBeDefined()
  })

  it('마우스 기기에서는 가로채지 않고 바로 삽입한다', () => {
    stubMedia({ coarse: false })
    render(<Shelf games={[playable]} />)
    openPopup('LAST LOGIN')
    fireEvent.click(screen.getByText('▶ PLAY'))
    expect(screen.queryByText(/PC 환경에서 플레이/)).toBeNull()
    expect(screen.getByLabelText(/카트리지를 삽입하는 중/)).toBeDefined()
  })

  it('플래그가 없는 게임은 터치에서도 가로채지 않는다', () => {
    stubMedia({ coarse: true })
    render(<Shelf games={[base]} />)
    openPopup('STARFALL DRIFT')
    fireEvent.click(screen.getByText('▶ PLAY'))
    expect(screen.queryByText(/PC 환경에서 플레이/)).toBeNull()
    expect(screen.getByLabelText(/카트리지를 삽입하는 중/)).toBeDefined()
  })
})
