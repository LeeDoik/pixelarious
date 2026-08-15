'use client'

import { useEffect, useState } from 'react'

const SITE_NAME = 'PIXELARIOUS'
const START_DELAY_MS = 600
const CHAR_DELAY_MS = 95
const FINISH_DELAY_MS = 250

export function Hero() {
  const [count, setCount] = useState(0)
  const [done, setDone] = useState(false)

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setCount(SITE_NAME.length)
      setDone(true)
      return
    }
    let i = 0
    let timer: ReturnType<typeof setTimeout>
    const tick = () => {
      i += 1
      setCount(i)
      timer =
        i < SITE_NAME.length
          ? setTimeout(tick, CHAR_DELAY_MS)
          : setTimeout(() => setDone(true), FINISH_DELAY_MS)
    }
    timer = setTimeout(tick, START_DELAY_MS)
    return () => clearTimeout(timer)
  }, [])

  return (
    <header className="hero">
      <h1>
        <span>
          {SITE_NAME.slice(0, count)
            .split('')
            .map((ch, i) => (
              <span key={i} className={done && ch === '_' ? 'u' : undefined}>
                {ch}
              </span>
            ))}
        </span>
        <span className="cursor">█</span>
      </h1>
      <div className={done ? 'scroll-hint show' : 'scroll-hint'}>
        SCROLL TO SELECT<span className="arr">▼</span>
      </div>
    </header>
  )
}
