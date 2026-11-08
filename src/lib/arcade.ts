import type { CoverScene } from './scenes'

export interface ArcadeProject {
  slug: string
  title: string
  subtitle?: string
  description: string
  tags: string[]
  kind: 'game' | 'software'
  category?: string
  coverScene: CoverScene
  coverImage?: string
  href: string | null
  pcRecommended?: boolean
}

export const ARCADE_COLORS = ['#ff71c5', '#65e1ff', '#ffc477', '#bba2ff']
export const TRAVEL_MS = 850

export function stationColor(index: number) {
  return ARCADE_COLORS[index % ARCADE_COLORS.length]
}

export function swipeDirection(dx: number, dy: number): -1 | 0 | 1 {
  const distance = Math.abs(dx) > Math.abs(dy) ? dx : dy
  return Math.abs(distance) < 36 ? 0 : distance < 0 ? 1 : -1
}

type WheelResult = 'hold' | 'release' | 'previous' | 'next'

/** A wheel/trackpad burst owns one move, including its inertial tail. */
export class ArcadeWheelGesture {
  private lastAt = -Infinity
  private distance = 0
  private consumed = false
  private released = false

  lock(now: number) {
    this.lastAt = now
    this.consumed = true
    this.released = false
    this.distance = 0
  }

  read(delta: number, now: number, index: number, count: number, busy = false): WheelResult {
    if (now - this.lastAt > 220) {
      this.distance = 0
      this.consumed = false
      this.released = false
    }
    this.lastAt = now
    if (this.released) return 'release'
    if (this.consumed) return 'hold'
    if (count === 0 || (index === 0 && delta < 0) || (index === count - 1 && delta > 0)) {
      this.released = true
      return 'release'
    }
    if (busy) {
      this.consumed = true
      return 'hold'
    }
    if (Math.sign(this.distance) !== Math.sign(delta)) this.distance = 0
    this.distance += delta
    if (Math.abs(this.distance) < 40) return 'hold'
    this.consumed = true
    return this.distance > 0 ? 'next' : 'previous'
  }
}
