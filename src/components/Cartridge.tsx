'use client'

import { useState } from 'react'
import Link from 'next/link'
import type { Game } from '@/lib/games'
import { CoverCanvas } from './CoverCanvas'

export function Cartridge({ game, index }: { game: Game; index: number }) {
  const [open, setOpen] = useState(false)
  const toggle = () => setOpen((o) => !o)

  return (
    <article className={open ? 'cart open' : 'cart'}>
      <div
        className="cart-strip"
        role="button"
        tabIndex={0}
        aria-expanded={open}
        onClick={toggle}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            toggle()
          }
        }}
      >
        <span className="cart-no">{String(index + 1).padStart(2, '0')}</span>
        <CoverCanvas scene={game.coverScene} />
        <h3 className="cart-title">
          {game.title}
          {game.subtitle && <span className="kr">{game.subtitle}</span>}
        </h3>
        <span className="cart-hint">
          <span className="open-ic">▼ OPEN</span>
          <span className="close-ic">▲</span>
        </span>
      </div>
      <div className="cart-detail">
        <div className="cart-detail-inner">
          <p className="desc">{game.description}</p>
          <div className="cart-detail-foot">
            <ul className="tags">
              {game.tags.map((t) => (
                <li key={t}>{t}</li>
              ))}
            </ul>
            {game.playPath ? (
              <Link className="btn" href={`/play/${game.slug}`}>
                ▶ PLAY
              </Link>
            ) : (
              <span className="btn not-inserted" aria-disabled="true">
                NOT INSERTED
              </span>
            )}
          </div>
        </div>
      </div>
    </article>
  )
}
