import { describe, expect, it } from 'vitest'
import { ArcadeWheelGesture, swipeDirection } from './arcade'

describe('arcade gestures', () => {
  it('consumes the entire inertial tail after advancing one cabinet', () => {
    const wheel = new ArcadeWheelGesture()
    expect(wheel.read(20, 0, 0, 3)).toBe('hold')
    expect(wheel.read(30, 20, 0, 3)).toBe('next')
    for (let time = 40; time < 1500; time += 20) {
      expect(wheel.read(70, time, 1, 3)).toBe('hold')
    }
    expect(wheel.read(50, 1800, 1, 3)).toBe('next')
  })

  it('keeps momentum on the last cabinet until a new gesture exits the arcade', () => {
    const wheel = new ArcadeWheelGesture()
    expect(wheel.read(80, 0, 1, 3)).toBe('next')
    expect(wheel.read(80, 30, 2, 3)).toBe('hold')
    expect(wheel.read(80, 900, 2, 3)).toBe('release')
    expect(wheel.read(8, 950, 2, 3)).toBe('release')
  })

  it('releases native scrolling at the entrance and for a single station', () => {
    expect(new ArcadeWheelGesture().read(-60, 0, 0, 3)).toBe('release')
    expect(new ArcadeWheelGesture().read(60, 0, 0, 1)).toBe('release')
    expect(new ArcadeWheelGesture().read(60, 0, 0, 0)).toBe('release')
  })

  it('absorbs the entry gesture and gestures begun during camera movement', () => {
    const wheel = new ArcadeWheelGesture()
    wheel.lock(0)
    expect(wheel.read(200, 80, 0, 3)).toBe('hold')
    expect(wheel.read(100, 400, 1, 3, true)).toBe('hold')
    expect(wheel.read(100, 500, 1, 3, false)).toBe('hold')
    expect(wheel.read(-50, 900, 1, 3)).toBe('previous')
  })

  it('does not add opposing wheel movements together', () => {
    const wheel = new ArcadeWheelGesture()
    expect(wheel.read(30, 0, 1, 3)).toBe('hold')
    expect(wheel.read(-25, 30, 1, 3)).toBe('hold')
    expect(wheel.read(-20, 50, 1, 3)).toBe('previous')
  })

  it('maps a deliberate swipe on either axis to one move and ignores taps', () => {
    expect(swipeDirection(12, -8)).toBe(0)
    expect(swipeDirection(-200, 15)).toBe(1)
    expect(swipeDirection(12, -100)).toBe(1)
    expect(swipeDirection(180, -20)).toBe(-1)
    expect(swipeDirection(-20, 140)).toBe(-1)
  })
})
