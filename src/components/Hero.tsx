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
    <header className="hero" id="entrance">
      <div className="lobby-scenery" aria-hidden="true">
        <div className="lobby-portal" />
        <div className="lobby-portal lobby-portal-inner" />
        <div className="lobby-floor" />
        <span className="lobby-wall-label">GAMES<br />&amp; SOFTWARE</span>
      </div>
      <div className="lobby-meta room-eyebrow"><span>00 / THE LOBBY</span><span className="room-status">FREE PLAY</span></div>
      <div className="lobby-sign"><span className="room-led" /> OPEN TO CURIOSITY</div>
      <h1 aria-label={done ? SITE_NAME : undefined}>
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
      <p className="lobby-intro">작은 게임과 소프트웨어가 모이는 곳.<br />마음에 드는 자리에서, 바로 시작하세요.</p>
      <div className="lobby-actions">
        <a href="#games" className={`arcade-button scroll-hint${done ? ' show' : ''}`}>
          ENTER THE ARCADE <span aria-hidden="true">↘</span>
        </a>
        <span className="lobby-scroll">SCROLL TO EXPLORE <span className="arr" aria-hidden="true">↓</span></span>
      </div>
      <div className="lobby-bottom"><span>INDEPENDENT GAMES &amp; SOFTWARE</span><span>NO COINS. JUST CURIOSITY.</span></div>
    </header>
  )
}
