'use client'

import { useEffect, useRef, useState } from 'react'
import type { Game } from '@/lib/games'
import { CartridgeArt } from './CartridgeArt'
import { GameDetail } from './GameDetail'
import { InsertSequence } from './InsertSequence'

/** 터치 기기? SSR/하이드레이션이 어긋나지 않게 클릭 시점에 판단한다. */
function isCoarsePointer(): boolean {
  return (
    typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function' &&
    window.matchMedia('(pointer: coarse)').matches
  )
}

export function Shelf({ games }: { games: Game[] }) {
  const [selected, setSelected] = useState<Game | null>(null)
  const [notice, setNotice] = useState<Game | null>(null)
  const [inserting, setInserting] = useState<Game | null>(null)
  const pkgRef = useRef<HTMLDivElement>(null)

  const closePopup = () => {
    setSelected(null)
    setNotice(null)
  }

  useEffect(() => {
    if (!selected) return
    pkgRef.current?.focus()
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return
      if (notice) setNotice(null)
      else closePopup()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [selected, notice])

  // 팝업/삽입 중에는 뒤편 페이지가 따라 구르지 않게 잠그다.
  useEffect(() => {
    if (!selected && !inserting) return
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.body.style.overflow = prev
    }
  }, [selected, inserting])

  const requestPlay = (game: Game) => {
    if (game.pcRecommended && isCoarsePointer()) {
      setNotice(game)
      return
    }
    startInsert(game)
  }

  const startInsert = (game: Game) => {
    setNotice(null)
    setSelected(null)
    setInserting(game)
  }

  return (
    <>
      <div className="shelf">
        {games.map((g, i) => (
          <div className="slot" key={g.slug}>
            <button
              type="button"
              className="slot-tile"
              aria-haspopup="dialog"
              aria-label={`${g.title} — 자세히 보기`}
              onClick={() => setSelected(g)}
            >
              <span className="slot-no">{String(i + 1).padStart(2, '0')}</span>
              <CartridgeArt game={g} />
            </button>
          </div>
        ))}
        <div className="slot">
          <div className="slot-tile empty">
            <span className="slot-no">{String(games.length + 1).padStart(2, '0')}</span>
            <div className="slot-empty-box">
              EMPTY SLOT
              <span className="kr">다음 게임 제작 중…</span>
            </div>
          </div>
        </div>
      </div>

      {selected && (
        <div className="pkg-overlay" onClick={closePopup}>
          <div
            className="pkg"
            ref={pkgRef}
            tabIndex={-1}
            role="dialog"
            aria-modal="true"
            aria-labelledby={`pkg-title-${selected.slug}`}
            onClick={(e) => e.stopPropagation()}
          >
            <button type="button" className="pkg-close" aria-label="닫기" onClick={closePopup}>
              ✕
            </button>
            <CartridgeArt game={selected} size="package">
              <GameDetail
                game={selected}
                titleId={`pkg-title-${selected.slug}`}
                onPlay={requestPlay}
              />
            </CartridgeArt>
          </div>

          {notice && (
            <div className="pc-notice-overlay" onClick={(e) => e.stopPropagation()}>
              <div
                className="pc-notice"
                role="dialog"
                aria-modal="true"
                aria-labelledby={`pc-notice-title-${notice.slug}`}
              >
                <h4 id={`pc-notice-title-${notice.slug}`} className="pc-notice-title">
                  ! NOTICE !
                </h4>
                <p className="pc-notice-body">
                  이 게임은 마우스 및 키보드 조작을 전제로 만들어졌습니다.
                  <br />
                  PC 환경에서 플레이하시는 것을 권장합니다.
                </p>
                <div className="pc-notice-foot">
                  <button
                    type="button"
                    className="btn pc-notice-cancel"
                    onClick={() => setNotice(null)}
                  >
                    돌아가기
                  </button>
                  <button type="button" className="btn" onClick={() => startInsert(notice)}>
                    ▶ 그래도 플레이
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {inserting && <InsertSequence game={inserting} />}
    </>
  )
}
