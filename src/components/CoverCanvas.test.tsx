import { describe, it, expect, afterEach } from 'vitest'
import { render, cleanup } from '@testing-library/react'
import { CoverCanvas } from './CoverCanvas'

afterEach(cleanup)

describe('CoverCanvas', () => {
  it('renders a pixelated cover canvas without crashing in jsdom', () => {
    // jsdom의 getContext는 null을 반환한다 — drawScene의 null 가드 경로 검증
    const { container } = render(<CoverCanvas scene="starfall" />)
    const canvas = container.querySelector('canvas.cover')
    expect(canvas).not.toBeNull()
    expect(canvas?.getAttribute('width')).toBe('100')
    expect(canvas?.getAttribute('aria-hidden')).toBe('true')
  })
})
