import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { NeonArcade } from './NeonArcade'
import type { ArcadeProject } from '@/lib/arcade'

const scene = vi.hoisted(() => ({ select: vi.fn(), setPalette: vi.fn(), setVisible: vi.fn(), setReducedMotion: vi.fn(), dispose: vi.fn() }))
const create = vi.hoisted(() => vi.fn(() => scene))
vi.mock('@/lib/arcade-scene', () => ({ createArcadeScene: create }))
vi.mock('./CoverCanvas', () => ({ CoverCanvas: () => <canvas /> }))
const observers: { callback: IntersectionObserverCallback; rootMargin?: string }[] = []
const first: ArcadeProject = { slug: 'first', title: 'FIRST GAME', description: '첫 게임\n게임 설명', tags: ['PC'], kind: 'game', coverScene: 'starfall', href: '/play/first' }
const projects: ArcadeProject[] = [first, { ...first, slug: 'second', title: 'SECOND GAME', href: '/play/second', pcRecommended: true }, { ...first, slug: 'app', title: 'SIDE PANEL', kind: 'software', href: 'https://example.com/project' }]

function visible() {
  act(() => observers.forEach(({ callback }) => callback([{ isIntersecting: true } as IntersectionObserverEntry], {} as IntersectionObserver)))
}

beforeEach(() => {
  observers.length = 0
  vi.clearAllMocks()
  create.mockImplementation(() => scene)
  vi.stubGlobal('IntersectionObserver', class {
    constructor(callback: IntersectionObserverCallback, options?: IntersectionObserverInit) { observers.push({ callback, rootMargin: options?.rootMargin }) }
    observe() {}
    disconnect() {}
  })
  vi.stubGlobal('matchMedia', (query: string) => ({ matches: query.includes('reduced-motion'), media: query, addEventListener: vi.fn(), removeEventListener: vi.fn() }))
  Object.defineProperties(HTMLDialogElement.prototype, {
    showModal: { configurable: true, value: function (this: HTMLDialogElement) { this.setAttribute('open', '') } },
    close: { configurable: true, value: function (this: HTMLDialogElement) { this.removeAttribute('open') } },
  })
})
afterEach(() => { cleanup(); vi.restoreAllMocks(); vi.unstubAllGlobals() })

describe('NeonArcade', () => {
  it('offers real project links before loading 3D, then disposes the scene on leaving', async () => {
    const view = render(<NeonArcade projects={projects} />)
    expect(create).not.toHaveBeenCalled()
    expect(screen.getByRole('link', { name: /START GAME/ }).getAttribute('href')).toBe('/play/first')
    visible()
    await waitFor(() => expect(create).toHaveBeenCalledTimes(1))
    view.unmount()
    expect(scene.dispose).toHaveBeenCalledTimes(1)
  })

  it('moves one station per burst while keeping the page still, and releases the next burst at the end', () => {
    render(<NeonArcade projects={projects} />)
    const region = screen.getByRole('region', { name: /네온 오락실/ })
    vi.spyOn(region, 'getBoundingClientRect').mockReturnValue({ top: 0, height: window.innerHeight, bottom: window.innerHeight } as DOMRect)
    const now = vi.spyOn(performance, 'now').mockReturnValue(0)
    expect(fireEvent.wheel(region, { deltaY: 60, cancelable: true })).toBe(false)
    expect(screen.getByRole('heading', { name: 'SECOND GAME' })).toBeDefined()
    now.mockReturnValue(30)
    fireEvent.wheel(region, { deltaY: 100, cancelable: true })
    expect(screen.getByRole('heading', { name: 'SECOND GAME' })).toBeDefined()
    now.mockReturnValue(500)
    fireEvent.wheel(region, { deltaY: 100, cancelable: true })
    expect(screen.getByRole('heading', { name: 'SIDE PANEL' })).toBeDefined()
    now.mockReturnValue(550)
    expect(fireEvent.wheel(region, { deltaY: 80, cancelable: true })).toBe(false)
    now.mockReturnValue(1000)
    expect(fireEvent.wheel(region, { deltaY: 80, cancelable: true })).toBe(true)
  })

  it('lands on the entrance when a large wheel event begins over the hero', () => {
    render(<NeonArcade projects={projects} />)
    const region = screen.getByRole('region')
    const bounds = vi.spyOn(region, 'getBoundingClientRect').mockReturnValue({ top: window.innerHeight, height: window.innerHeight, bottom: window.innerHeight * 2 } as DOMRect)
    region.scrollIntoView = vi.fn()
    vi.spyOn(performance, 'now').mockReturnValue(0)
    expect(fireEvent.wheel(window, { deltaY: window.innerHeight * 2, cancelable: true })).toBe(false)
    expect(region.scrollIntoView).toHaveBeenCalledTimes(1)
    bounds.mockReturnValue({ top: 0, height: window.innerHeight, bottom: window.innerHeight } as DOMRect)
    fireEvent.wheel(window, { deltaY: 100, cancelable: true })
    expect(screen.getByRole('heading', { name: 'FIRST GAME' })).toBeDefined()
  })

  it('keeps navigation and links usable if WebGL is unavailable', async () => {
    create.mockImplementationOnce(() => { throw new Error('WebGL unavailable') })
    render(<NeonArcade projects={projects} />)
    visible()
    await waitFor(() => expect(screen.getByRole('region').dataset.renderer).toBe('fallback'))
    fireEvent.click(screen.getByRole('button', { name: '다음 자리' }))
    expect(screen.getByRole('link', { name: /START GAME/ }).getAttribute('href')).toBe('/play/second')
    fireEvent.click(screen.getByRole('button', { name: '3. SIDE PANEL' }))
    const link = screen.getByRole('link', { name: /OPEN PROJECT/ })
    expect(link.getAttribute('href')).toBe('https://example.com/project')
    expect(link.getAttribute('rel')).toContain('noopener')
  })

  it('scopes arrow keys to the arcade and ignores key repeats', () => {
    render(<NeonArcade projects={projects} />)
    fireEvent.keyDown(window, { key: 'ArrowDown' })
    expect(screen.getByRole('heading', { name: 'FIRST GAME' })).toBeDefined()
    const region = screen.getByRole('region')
    fireEvent.keyDown(region, { key: 'ArrowDown' })
    fireEvent.keyDown(region, { key: 'ArrowDown', repeat: true })
    expect(screen.getByRole('heading', { name: 'SECOND GAME' })).toBeDefined()
  })

  it('shows the full introduction, locks background scrolling, and closes on cancel', () => {
    render(<NeonArcade projects={projects} />)
    fireEvent.click(screen.getByRole('button', { name: /작품 소개/ }))
    expect(screen.getByRole('dialog').textContent).toContain('게임 설명')
    expect(document.body.style.overflow).toBe('hidden')
    fireEvent(screen.getByRole('dialog'), new Event('cancel', { bubbles: true }))
    expect(screen.queryByRole('dialog')).toBeNull()
    expect(document.body.style.overflow).toBe('')
  })

  it('recommends PC on touch devices without blocking the option to play', () => {
    vi.stubGlobal('matchMedia', (query: string) => ({ matches: query.includes('pointer: coarse'), media: query, addEventListener: vi.fn(), removeEventListener: vi.fn() }))
    render(<NeonArcade projects={projects} />)
    fireEvent.click(screen.getByRole('button', { name: '2. SECOND GAME' }))
    fireEvent.click(screen.getByRole('link', { name: /START GAME/ }))
    expect(screen.getByRole('dialog').textContent).toContain('마우스 조작')
    expect(screen.getByRole('link', { name: '그래도 플레이' }).getAttribute('href')).toBe('/play/second')
  })

  it('leaves short viewports and browser zoom gestures to native scrolling', () => {
    render(<NeonArcade projects={projects} />)
    const region = screen.getByRole('region')
    vi.spyOn(region, 'getBoundingClientRect').mockReturnValue({ top: 0, height: window.innerHeight + 200 } as DOMRect)
    expect(fireEvent.wheel(region, { deltaY: 100, cancelable: true })).toBe(true)
    expect(fireEvent.wheel(region, { deltaY: 100, ctrlKey: true, cancelable: true })).toBe(true)
    expect(screen.getByRole('heading', { name: 'FIRST GAME' })).toBeDefined()
  })
})
