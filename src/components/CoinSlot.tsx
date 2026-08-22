'use client'

import { useRef, useState } from 'react'
import { CoinFace } from './CoinFace'

/**
 * 아케이드 캐비닛의 코인 억셉터. 왼쪽에 동전이 놓여 있고 오른쪽 투입구에는
 * 세로 슬릿과 INSERT COIN / 1 PLAY 안내가 박혀 있다. 동전을 오른쪽으로 끌어
 * 슬릿에 넣는다.
 *
 * 드래그는 포인터 이벤트로 처리한다 — HTML5 드래그는 터치에서 동작하지 않는다.
 * touch-action:none은 동전에만 건다. 억셉터 전체에 걸면 그 위에서 페이지가
 * 스크롤되지 않아 모바일에서 큰 죽은 구역이 생긴다.
 *
 * 동전은 앵커다. 그냥 누르거나 키보드로 활성화하면 브라우저가 알아서 연다.
 * 드래그로 넣었을 때는 pointerup 안에서 곧바로 window.open을 부른다. 애니메이션이
 * 끝나기를 기다렸다 열면 사용자 제스처가 끊겨 팝업 차단에 걸린다.
 *
 * 후원은 언제나 새 창에서만 연다. 현재 탭을 후원 페이지로 돌리는 경로는 두지
 * 않는다 — 보던 게임 페이지가 사라지면 안 된다. 팝업이 막히면 아무 데도 가지
 * 않고 동전을 눌러 달라고 알린다(직접 클릭은 차단되지 않는다).
 *
 * 후원 주소가 없으면 아무것도 그리지 않는다.
 */

/** 동전이 슬릿에 먹히는 시간 */
const ACCEPT_MS = 420
/** 슬릿 판정 여유 — 정확히 12px 슬릿에 맞추라고 하면 잔인하다 */
const HIT_PAD = 28

type Phase = 'idle' | 'dragging' | 'accepted'

export function CoinSlot({ href }: { href?: string }) {
  const [phase, setPhase] = useState<Phase>('idle')
  const [offset, setOffset] = useState({ x: 0, y: 0 })
  const [credit, setCredit] = useState(0)
  const [blocked, setBlocked] = useState(false)
  const slitRef = useRef<HTMLSpanElement>(null)
  const start = useRef({ x: 0, y: 0 })
  /** 동전이 포인터를 따라다니므로 드래그 후에도 앵커 위에서 click이 발생한다.
   *  막지 않으면 새 탭과 별개로 이 탭까지 후원 페이지로 넘어간다. */
  const dragged = useRef(false)
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null)

  if (!href) return null

  const overSlit = (x: number, y: number) => {
    const r = slitRef.current?.getBoundingClientRect()
    if (!r) return false
    return (
      x >= r.left - HIT_PAD && x <= r.right + HIT_PAD && y >= r.top - HIT_PAD && y <= r.bottom + HIT_PAD
    )
  }

  const onPointerDown = (e: React.PointerEvent<HTMLAnchorElement>) => {
    if (phase === 'accepted') return
    e.currentTarget.setPointerCapture(e.pointerId)
    start.current = { x: e.clientX, y: e.clientY }
    dragged.current = false
    setPhase('dragging')
  }

  const onPointerMove = (e: React.PointerEvent<HTMLAnchorElement>) => {
    if (phase !== 'dragging') return
    const dx = e.clientX - start.current.x
    const dy = e.clientY - start.current.y
    if (Math.hypot(dx, dy) > 6) dragged.current = true
    setOffset({ x: dx, y: dy })
  }

  const onPointerUp = (e: React.PointerEvent<HTMLAnchorElement>) => {
    if (phase !== 'dragging') return
    const moved = dragged.current
    if (!moved) {
      // 끌지 않고 눌렀다 뗀 것 — 앵커가 알아서 연다
      setPhase('idle')
      setOffset({ x: 0, y: 0 })
      return
    }
    e.preventDefault()
    if (!overSlit(e.clientX, e.clientY)) {
      // 빗나갔다 — 손에서 놓친 동전처럼 제자리로
      setPhase('idle')
      setOffset({ x: 0, y: 0 })
      return
    }

    // 슬릿 중앙으로 끌려들어간 뒤 사라진다
    const r = slitRef.current!.getBoundingClientRect()
    const c = e.currentTarget.getBoundingClientRect()
    setOffset({
      x: offset.x + (r.left + r.width / 2 - (c.left + c.width / 2)),
      y: offset.y + (r.top + r.height / 2 - (c.top + c.height / 2)),
    })
    setPhase('accepted')
    setCredit((n) => Math.min(n + 1, 99))

    // 제스처가 살아 있는 지금, 새 창으로만 연다. 막히면 현재 페이지는 그대로 둔다
    const win = window.open(href, '_blank', 'noopener,noreferrer')
    setBlocked(!win)

    if (timer.current) clearTimeout(timer.current)
    timer.current = setTimeout(() => {
      setPhase('idle')
      setOffset({ x: 0, y: 0 })
    }, ACCEPT_MS)
  }

  const cls = ['coin-acceptor', phase === 'dragging' && 'armed', phase === 'accepted' && 'taken']
    .filter(Boolean)
    .join(' ')

  return (
    <section className="sec coin-sec" id="continue">
      <div className={cls}>
        <div className="acceptor-tray">
          <a
            className={phase === 'idle' ? 'coin-piece' : `coin-piece ${phase}`}
            href={href}
            target="_blank"
            rel="noopener noreferrer"
            draggable={false}
            style={{ transform: `translate(${offset.x}px, ${offset.y}px)` }}
            onClick={(e) => {
              if (!dragged.current) return // 그냥 누른 것 — 앵커에 맡긴다
              e.preventDefault()
              dragged.current = false
            }}
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerCancel={() => {
              setPhase('idle')
              setOffset({ x: 0, y: 0 })
            }}
            aria-label="동전을 투입구로 끌어다 놓으세요 — 새 창에서 투네이션 후원 페이지로 이동합니다"
          >
            <CoinFace />
          </a>
          <span className="acceptor-credit">
            CREDIT <span className="acceptor-credit-n">{String(credit).padStart(2, '0')}</span>
          </span>
          {blocked && (
            <span className="acceptor-blocked" role="status">
              팝업이 막혔습니다 — 동전을 눌러 주세요
            </span>
          )}
        </div>
        <div className="acceptor-face">
          <span className="acceptor-screw acceptor-screw-tl" aria-hidden="true" />
          <span className="acceptor-screw acceptor-screw-bl" aria-hidden="true" />
          <div className="acceptor-bezel" aria-hidden="true">
            <span className="acceptor-arrow">▼</span>
            <span className="acceptor-slit" ref={slitRef} />
          </div>
          <div className="acceptor-lines">
            <span className="acceptor-lead">INSERT COIN</span>
            <span className="acceptor-play">1 PLAY</span>
            <span className="acceptor-scan" aria-hidden="true" />
            <span className="acceptor-hint">DRAG TO INSERT</span>
          </div>
        </div>

      </div>
    </section>
  )
}
