'use client'

import { useEffect, useRef, useState } from 'react'
import { track } from '@vercel/analytics'

/** 로딩을 견딘 사람만 이 시간을 넘긴다 — 진입과 플레이를 가르는 선. */
export const ENGAGED_MS = 15000

/**
 * 게임 iframe. 페이지뷰(/play/[slug])는 진입까지만 말해주므로, 실제로 게임이
 * 떴는지와 붙잡혀 있었는지를 따로 센다.
 *
 * - game_start   iframe 셸이 뜬 시점. Godot은 셸이 먼저 뜨고 wasm·pck를 그 뒤에
 *                받으므로 "부팅 시작"이지 "플레이 시작"이 아니다
 * - game_engaged 15초를 넘긴 시점. 로딩을 기다리다 떠난 사람이 걸러진다
 */
export function PlayFrame({
  slug,
  title,
  playPath,
}: {
  slug: string
  title: string
  playPath: string
}) {
  const [started, setStarted] = useState(false)
  // 개발 중 StrictMode는 effect를 두 번 돈다. 두 번 쏘면 수치가 부푼다.
  const engagedSent = useRef(false)

  useEffect(() => {
    if (!started || engagedSent.current) return
    const t = setTimeout(() => {
      engagedSent.current = true
      track('game_engaged', { slug, title })
    }, ENGAGED_MS)
    return () => clearTimeout(t)
  }, [started, slug, title])

  return (
    <iframe
      className="play-frame"
      src={playPath}
      title={title}
      allow="fullscreen; gamepad; autoplay"
      onLoad={() => {
        if (started) return
        setStarted(true)
        track('game_start', { slug, title })
      }}
    />
  )
}
