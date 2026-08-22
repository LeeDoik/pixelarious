'use client'

import type { Game } from '@/lib/games'
import { COVER_SCENES, type CoverScene } from '@/lib/scenes'
import styles from './EditorClient.module.css'

export interface GameDraft {
  title: string
  subtitle: string
  description: string
  tags: string
  coverScene: CoverScene
}

export function toGameDraft(game: Game): GameDraft {
  return {
    title: game.title,
    subtitle: game.subtitle ?? '',
    description: game.description,
    tags: game.tags.join(', '),
    coverScene: game.coverScene,
  }
}

export function parseTags(value: string): string[] {
  return value
    .split(',')
    .map((tag) => tag.trim())
    .filter(Boolean)
}

export function EditorGameForm({
  draft,
  onChange,
}: {
  draft: GameDraft
  onChange: (patch: Partial<GameDraft>) => void
}) {
  return (
    <>
      <label className={styles.field}>
        <span className={styles.label}>TITLE</span>
        <input
          className={styles.input}
          value={draft.title}
          onChange={(e) => onChange({ title: e.target.value })}
        />
      </label>

      <label className={styles.field}>
        <span className={styles.label}>SUBTITLE (한글 부제 · 비우면 표시 안 함)</span>
        <input
          className={styles.input}
          value={draft.subtitle}
          onChange={(e) => onChange({ subtitle: e.target.value })}
        />
      </label>

      <label className={styles.field}>
        <span className={styles.label}>DESCRIPTION</span>
        <textarea
          className={styles.textarea}
          value={draft.description}
          onChange={(e) => onChange({ description: e.target.value })}
        />
        <p className={styles.hint}>
          엔터로 줄을 나누면 팝업에도 그대로 나옵니다. 빈 줄을 넣으면 문단이 갈라집니다.
        </p>
      </label>

      <label className={styles.field}>
        <span className={styles.label}>TAGS (쉼표로 구분)</span>
        <input
          className={styles.input}
          value={draft.tags}
          onChange={(e) => onChange({ tags: e.target.value })}
        />
      </label>

      <label className={styles.field}>
        <span className={styles.label}>COVER</span>
        <select
          className={styles.select}
          value={draft.coverScene}
          onChange={(e) => onChange({ coverScene: e.target.value as CoverScene })}
        >
          {COVER_SCENES.map((scene) => (
            <option key={scene} value={scene}>
              {scene}
            </option>
          ))}
        </select>
      </label>
    </>
  )
}
