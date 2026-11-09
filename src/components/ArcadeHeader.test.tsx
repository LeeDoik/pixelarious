import { act, cleanup, render, screen, within } from '@testing-library/react'
import { afterEach, expect, it, vi } from 'vitest'
import { ArcadeHeader } from './ArcadeHeader'

afterEach(() => { cleanup(); vi.unstubAllGlobals() })

it('follows the visible room without changing navigation targets, and disconnects on unmount', () => {
  let observeRoom: IntersectionObserverCallback = () => {}
  const disconnect = vi.fn()
  vi.stubGlobal('IntersectionObserver', class {
    constructor(callback: IntersectionObserverCallback) { observeRoom = callback }
    observe() {}
    disconnect = disconnect
  })
  const view = render(<><ArcadeHeader /><section id="entrance" /><section id="games" /><section id="about" /></>)
  const navigation = within(screen.getByRole('navigation', { name: '오락실 안내' }))
  expect(navigation.getByRole('link', { name: '00 입구' }).getAttribute('aria-current')).toBe('location')
  const target = document.getElementById('games')!
  const bounds = target.getBoundingClientRect()
  act(() => observeRoom([{
    isIntersecting: true, target, time: 0, intersectionRatio: 1,
    boundingClientRect: bounds, intersectionRect: bounds, rootBounds: null,
  }], {} as IntersectionObserver))
  expect(navigation.getByRole('link', { name: '01 작품' }).getAttribute('aria-current')).toBe('location')
  expect(navigation.getByRole('link', { name: '00 입구' }).hasAttribute('aria-current')).toBe(false)
  expect(navigation.getByRole('link', { name: '02 제작자' }).getAttribute('href')).toBe('#about')
  view.unmount()
  expect(disconnect).toHaveBeenCalledOnce()
})

it('keeps section links and the theme control usable without IntersectionObserver', () => {
  vi.stubGlobal('IntersectionObserver', undefined)
  render(<ArcadeHeader />)
  expect(screen.getByRole('link', { name: '01 작품' }).getAttribute('href')).toBe('#games')
  expect(screen.getByRole('button', { name: /PALETTE/ })).toBeDefined()
})
