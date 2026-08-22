'use client'

import type { Game } from '@/lib/games'

/** 카트리지 라벨에 인쇄되는 내용 — 제목부터 PLAY까지 세로로 쌓는다. */
export function GameDetail({
  game,
  titleId,
  onPlay,
}: {
  game: Game
  titleId: string
  onPlay?: (game: Game) => void
}) {
  return (
    <div className="pkg-body">
      <h3 id={titleId} className="pkg-title">
        {game.title}
        {game.subtitle && <span className="kr">{game.subtitle}</span>}
      </h3>
      <p className="desc">{game.description}</p>
      <ul className="tags">
        {game.tags.map((t) => (
          <li key={t}>{t}</li>
        ))}
      </ul>
      <div className="pkg-foot">
        {game.playPath ? (
          <button type="button" className="btn" onClick={() => onPlay?.(game)} disabled={!onPlay}>
            ▶ PLAY
          </button>
        ) : (
          <span className="btn not-inserted" aria-disabled="true">
            NOT INSERTED
          </span>
        )}
      </div>
    </div>
  )
}
