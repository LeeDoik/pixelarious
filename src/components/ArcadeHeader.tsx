'use client'

import { useEffect, useState } from 'react'
import { PaletteSwap } from './PaletteSwap'

const rooms = [
  { id: 'entrance', number: '00', label: '입구' },
  { id: 'games', number: '01', label: '작품' },
  { id: 'about', number: '02', label: '제작자' },
]

export function ArcadeHeader() {
  const [active, setActive] = useState('entrance')

  useEffect(() => {
    if (typeof IntersectionObserver === 'undefined') return
    const observer = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) setActive(entry.target.id)
      }
    }, { rootMargin: '-25% 0px -45% 0px' })
    rooms.forEach(({ id }) => {
      const room = document.getElementById(id)
      if (room) observer.observe(room)
    })
    return () => observer.disconnect()
  }, [])

  return (
    <div className="arcade-header">
      <a className="arcade-skip" href="#games">작품 전시로 바로가기</a>
      <a href="#entrance" className="arcade-brand" aria-label="PIXELARIOUS 입구">
        <span className="arcade-brand-mark" aria-hidden="true">P<span>+</span></span>
        PIXELARIOUS
      </a>
      <nav className="arcade-wayfinding" aria-label="오락실 안내">
        {rooms.map((room) => (
          <a key={room.id} href={`#${room.id}`} aria-current={active === room.id ? 'location' : undefined}>
            <span>{room.number}</span> {room.label}
          </a>
        ))}
      </nav>
      <PaletteSwap compact />
    </div>
  )
}
