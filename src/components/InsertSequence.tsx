'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import type { Game } from '@/lib/games'
import { CartridgeArt } from './CartridgeArt'

/**
 * 콘솔이 등장 → 카트리지가 슬롯으로 내려감 → 철컥(착지 반동) → 전원이 들어옴
 * → 화면이 빨려들어가며 게임으로. 마지막 launch 단계가 라우트 전환의 딱 끊기는
 * 느낌을 먹어준다.
 */
export type InsertPhase = 'enter' | 'insert' | 'clunk' | 'power' | 'launch'

export const PHASE_MS: Record<InsertPhase, number> = {
  enter: 380,
  insert: 800,
  clunk: 420,
  power: 1100,
  launch: 340,
}

const ORDER: InsertPhase[] = ['enter', 'insert', 'clunk', 'power', 'launch']

function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  )
}

export function InsertSequence({ game }: { game: Game }) {
  const router = useRouter()
  const [phase, setPhase] = useState<InsertPhase>('enter')
  const [done, setDone] = useState(false)
  const href = `/play/${game.slug}`

  // 애니메이션이 도는 동안 미리 라우트를 받아둔다 — 게임 iframe은 여기서 띄우지
  // 않는다. 숨긴 채로 띄우면 사운드까지 두 번 부팅된다.
  useEffect(() => {
    router.prefetch(href)
  }, [router, href])

  useEffect(() => {
    if (done) return
    if (prefersReducedMotion()) {
      setDone(true)
      router.push(href)
      return
    }
    const i = ORDER.indexOf(phase)
    const t = setTimeout(() => {
      if (i === ORDER.length - 1) {
        setDone(true)
        router.push(href)
      } else {
        setPhase(ORDER[i + 1])
      }
    }, PHASE_MS[phase])
    return () => clearTimeout(t)
  }, [phase, done, router, href])

  // 기다리기 싫으면 아무 키나 클릭으로 건너뛴다.
  const skip = () => {
    if (done) return
    setDone(true)
    router.push(href)
  }
  useEffect(() => {
    const onKey = () => skip()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })

  const lit = phase === 'power' || phase === 'launch'

  return (
    <div
      className="insert-overlay"
      data-phase={phase}
      role="dialog"
      aria-modal="true"
      aria-label={`${game.title} 카트리지를 삽입하는 중`}
      onClick={skip}
    >
      <div className="insert-stage">
        {/* 흔들림은 래퍼가 맡는다 — 콘솔 자신에게 걸면 등장 애니메이션이 잘렸다
            다시 재생되면서 전원이 들어오는 순간 한 번 튄다. */}
        <div className="console-shake">
          <div className={lit ? 'console lit' : 'console'}>
            <div className="console-mouth">
              <span className="mouth-hole" />
            </div>
            <div className="console-screen">
              <span className="scanline" />
              <p className="boot-log">
                <span>&gt; CARTRIDGE DETECTED</span>
                <span>&gt; {game.title}</span>
                <span>&gt; LOADING…</span>
              </p>
            </div>
            <div className="console-face">
              <span className="led" />
              <span className="console-brand">PIXELARIOUS</span>
              <span className="console-btns">
                <i />
                <i />
              </span>
            </div>
          </div>
        </div>
        <div className="cart-flight">
          <CartridgeArt game={game} />
        </div>
      </div>
      <p className="insert-skip">CLICK / ANY KEY TO SKIP</p>
    </div>
  )
}
