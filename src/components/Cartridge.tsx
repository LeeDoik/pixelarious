'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import type { Game } from '@/lib/games'
import { CoverCanvas } from './CoverCanvas'

/** Touch-first device? Decided at click time so SSR/hydration never disagree. */
function isCoarsePointer(): boolean {
  return (
    typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function' &&
    window.matchMedia('(pointer: coarse)').matches
  )
}

export function Cartridge({
  game,
  index,
  defaultOpen = false,
}: {
  game: Game
  index: number
  defaultOpen?: boolean
}) {
  const [open, setOpen] = useState(defaultOpen)
  const [pcNotice, setPcNotice] = useState(false)
  const toggle = () => setOpen((o) => !o)

  useEffect(() => {
    if (!pcNotice) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setPcNotice(false)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [pcNotice])

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
        <CoverCanvas scene={game.coverScene} image={game.coverImage} />
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
              <Link
                className="btn"
                href={`/play/${game.slug}`}
                onClick={(e) => {
                  if (game.pcRecommended && isCoarsePointer()) {
                    e.preventDefault()
                    setPcNotice(true)
                  }
                }}
              >
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
      {pcNotice && (
        <div className="pc-notice-overlay" onClick={() => setPcNotice(false)}>
          <div
            className="pc-notice"
            role="dialog"
            aria-modal="true"
            aria-labelledby={`pc-notice-title-${game.slug}`}
            onClick={(e) => e.stopPropagation()}
          >
            <h4 id={`pc-notice-title-${game.slug}`} className="pc-notice-title">
              ! NOTICE !
            </h4>
            <p className="pc-notice-body">
              이 게임은 마우스 조작을 전제로 만들어졌습니다.
              <br />
              PC 환경에서 플레이하시는 것을 권장합니다.
            </p>
            <div className="pc-notice-foot">
              <button type="button" className="btn pc-notice-cancel" onClick={() => setPcNotice(false)}>
                돌아가기
              </button>
              <Link className="btn" href={`/play/${game.slug}`}>
                ▶ 그래도 플레이
              </Link>
            </div>
          </div>
        </div>
      )}
    </article>
  )
}
