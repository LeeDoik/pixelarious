'use client'

import { useState } from 'react'
import type { Game } from '@/lib/games'
import { COVER_SCENES, type CoverScene } from '@/lib/scenes'
import { Cartridge } from './Cartridge'
import { PaletteSwap } from './PaletteSwap'
import styles from './EditorClient.module.css'

interface Draft {
  title: string
  subtitle: string
  description: string
  tags: string
  coverScene: CoverScene
}

type Status =
  | { kind: 'idle' }
  | { kind: 'saving' }
  | { kind: 'ok'; message: string }
  | { kind: 'error'; message: string }

function toDraft(game: Game): Draft {
  return {
    title: game.title,
    subtitle: game.subtitle ?? '',
    description: game.description,
    tags: game.tags.join(', '),
    coverScene: game.coverScene,
  }
}

function draftsOf(games: Game[]): Record<string, Draft> {
  return Object.fromEntries(games.map((g) => [g.slug, toDraft(g)]))
}

function parseTags(value: string): string[] {
  return value
    .split(',')
    .map((tag) => tag.trim())
    .filter(Boolean)
}

export function EditorClient({ games }: { games: Game[] }) {
  const [savedDrafts, setSavedDrafts] = useState(() => draftsOf(games))
  const [drafts, setDrafts] = useState(() => draftsOf(games))
  const [slug, setSlug] = useState(games[0]?.slug ?? '')
  const [status, setStatus] = useState<Status>({ kind: 'idle' })

  const game = games.find((g) => g.slug === slug)
  const draft = drafts[slug]
  if (!game || !draft) {
    return <p className={styles.page}>편집할 카트리지가 없습니다.</p>
  }

  const index = games.findIndex((g) => g.slug === slug)
  const dirty = JSON.stringify(draft) !== JSON.stringify(savedDrafts[slug])

  const edit = (patch: Partial<Draft>) => {
    setDrafts((all) => ({ ...all, [slug]: { ...all[slug], ...patch } }))
    setStatus({ kind: 'idle' })
  }

  const preview: Game = {
    ...game,
    title: draft.title.trim() || '(제목 없음)',
    subtitle: draft.subtitle.trim() || undefined,
    description: draft.description.trim() || '(설명 없음)',
    tags: parseTags(draft.tags),
    coverScene: draft.coverScene,
  }

  async function save() {
    setStatus({ kind: 'saving' })
    try {
      const response = await fetch('/api/editor', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          slug,
          patch: {
            title: draft.title.trim(),
            subtitle: draft.subtitle,
            description: draft.description,
            tags: parseTags(draft.tags),
            coverScene: draft.coverScene,
          },
        }),
      })
      const data = await response.json().catch(() => ({}))
      if (!response.ok) {
        setStatus({ kind: 'error', message: data.error ?? '저장하지 못했습니다.' })
        return
      }
      setSavedDrafts((all) => ({ ...all, [slug]: { ...draft } }))
      setStatus({ kind: 'ok', message: `${slug}.json에 저장했습니다.` })
    } catch {
      setStatus({ kind: 'error', message: '개발 서버에 연결하지 못했습니다.' })
    }
  }

  return (
    <div className={styles.page}>
      <PaletteSwap />

      <h1 className={styles.head}>
        <span className={styles.deco}>►</span> CARTRIDGE EDITOR
      </h1>
      <p className={styles.sub}>
        배너에 들어가는 내용을 고치고 저장하면 <code>content/games</code>의 파일에 그대로 기록됩니다.
        개발 서버에서만 열리는 편집기입니다.
      </p>

      <div className={styles.picker}>
        {games.map((g) => {
          const changed = JSON.stringify(drafts[g.slug]) !== JSON.stringify(savedDrafts[g.slug])
          return (
            <button
              key={g.slug}
              type="button"
              className={g.slug === slug ? `${styles.pick} ${styles.pickOn}` : styles.pick}
              onClick={() => {
                setSlug(g.slug)
                setStatus({ kind: 'idle' })
              }}
            >
              {g.title}
              {changed && <span className={styles.dot}> ●</span>}
            </button>
          )
        })}
      </div>

      <div className={styles.cols}>
        <section className={styles.panel}>
          <h2 className={styles.panelTitle}>EDIT</h2>

          <label className={styles.field}>
            <span className={styles.label}>TITLE</span>
            <input
              className={styles.input}
              value={draft.title}
              onChange={(e) => edit({ title: e.target.value })}
            />
          </label>

          <label className={styles.field}>
            <span className={styles.label}>SUBTITLE (한글 부제 · 비우면 표시 안 함)</span>
            <input
              className={styles.input}
              value={draft.subtitle}
              onChange={(e) => edit({ subtitle: e.target.value })}
            />
          </label>

          <label className={styles.field}>
            <span className={styles.label}>DESCRIPTION</span>
            <textarea
              className={styles.textarea}
              value={draft.description}
              onChange={(e) => edit({ description: e.target.value })}
            />
            <p className={styles.hint}>
              엔터로 줄을 나누면 배너에도 그대로 나옵니다. 빈 줄을 넣으면 문단이 갈라집니다.
            </p>
          </label>

          <label className={styles.field}>
            <span className={styles.label}>TAGS (쉼표로 구분)</span>
            <input
              className={styles.input}
              value={draft.tags}
              onChange={(e) => edit({ tags: e.target.value })}
            />
          </label>

          <label className={styles.field}>
            <span className={styles.label}>COVER</span>
            <select
              className={styles.select}
              value={draft.coverScene}
              onChange={(e) => edit({ coverScene: e.target.value as CoverScene })}
            >
              {COVER_SCENES.map((scene) => (
                <option key={scene} value={scene}>
                  {scene}
                </option>
              ))}
            </select>
          </label>

          <div className={styles.actions}>
            <button className="btn" type="button" onClick={save} disabled={status.kind === 'saving'}>
              {status.kind === 'saving' ? 'SAVING…' : '저장'}
            </button>
            {dirty && (
              <button
                className="btn not-inserted"
                type="button"
                onClick={() => {
                  setDrafts((all) => ({ ...all, [slug]: { ...savedDrafts[slug] } }))
                  setStatus({ kind: 'idle' })
                }}
              >
                되돌리기
              </button>
            )}
            <span className={styles.status}>
              {status.kind === 'ok' && <span className={styles.ok}>{status.message}</span>}
              {status.kind === 'error' && <span className={styles.err}>{status.message}</span>}
              {status.kind === 'idle' && dirty && (
                <span className={styles.dirty}>저장하지 않은 변경이 있습니다</span>
              )}
            </span>
          </div>
        </section>

        <section className={styles.panel}>
          <h2 className={styles.panelTitle}>PREVIEW</h2>
          <div className="carts">
            <Cartridge game={preview} index={index} defaultOpen />
          </div>
          <p className={styles.previewNote}>
            실제 배너 그대로입니다. 팔레트를 바꿔 두 테마에서 모두 확인해 보세요.
          </p>
        </section>
      </div>
    </div>
  )
}
