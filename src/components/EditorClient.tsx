'use client'

import { useState } from 'react'
import type { Game } from '@/lib/games'
import type { Profile } from '@/lib/profile'
import { Cartridge } from './Cartridge'
import { Player1 } from './Player1'
import { PaletteSwap } from './PaletteSwap'
import { EditorGameForm, parseTags, toGameDraft, type GameDraft } from './EditorGameForm'
import {
  EditorProfileForm,
  parseBadges,
  toProfileDraft,
  usableLinks,
  type ProfileDraft,
} from './EditorProfileForm'
import styles from './EditorClient.module.css'

type Target = { kind: 'game'; slug: string } | { kind: 'profile' }

type Status =
  | { kind: 'idle' }
  | { kind: 'saving' }
  | { kind: 'ok'; message: string }
  | { kind: 'error'; message: string }

const changed = (a: unknown, b: unknown) => JSON.stringify(a) !== JSON.stringify(b)

export function EditorClient({ games, profile }: { games: Game[]; profile: Profile }) {
  const [savedGames, setSavedGames] = useState(() =>
    Object.fromEntries(games.map((g) => [g.slug, toGameDraft(g)])),
  )
  const [gameDrafts, setGameDrafts] = useState(() =>
    Object.fromEntries(games.map((g) => [g.slug, toGameDraft(g)])),
  )
  const [savedProfile, setSavedProfile] = useState(() => toProfileDraft(profile))
  const [profileDraft, setProfileDraft] = useState(() => toProfileDraft(profile))
  const [target, setTarget] = useState<Target>(
    games[0] ? { kind: 'game', slug: games[0].slug } : { kind: 'profile' },
  )
  const [status, setStatus] = useState<Status>({ kind: 'idle' })

  const select = (next: Target) => {
    setTarget(next)
    setStatus({ kind: 'idle' })
  }

  const editGame = (patch: Partial<GameDraft>) => {
    if (target.kind !== 'game') return
    const slug = target.slug
    setGameDrafts((all) => ({ ...all, [slug]: { ...all[slug], ...patch } }))
    setStatus({ kind: 'idle' })
  }

  const editProfile = (patch: Partial<ProfileDraft>) => {
    setProfileDraft((draft) => ({ ...draft, ...patch }))
    setStatus({ kind: 'idle' })
  }

  const game = target.kind === 'game' ? games.find((g) => g.slug === target.slug) : undefined
  const gameDraft = target.kind === 'game' ? gameDrafts[target.slug] : undefined

  const dirty =
    target.kind === 'profile'
      ? changed(profileDraft, savedProfile)
      : changed(gameDraft, savedGames[target.slug])

  async function save() {
    setStatus({ kind: 'saving' })
    const body =
      target.kind === 'profile'
        ? {
            target: 'profile',
            patch: {
              intro: profileDraft.intro,
              links: usableLinks(profileDraft.links),
              badges: parseBadges(profileDraft.badges),
            },
          }
        : {
            target: 'game',
            slug: target.slug,
            patch: {
              title: gameDraft!.title.trim(),
              subtitle: gameDraft!.subtitle,
              description: gameDraft!.description,
              tags: parseTags(gameDraft!.tags),
              coverScene: gameDraft!.coverScene,
            },
          }

    try {
      const response = await fetch('/api/editor', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
      const data = await response.json().catch(() => ({}))
      if (!response.ok) {
        setStatus({ kind: 'error', message: data.error ?? '저장하지 못했습니다.' })
        return
      }
      if (target.kind === 'profile') {
        setSavedProfile({ ...profileDraft })
        setStatus({ kind: 'ok', message: 'profile.json에 저장했습니다.' })
      } else {
        const slug = target.slug
        setSavedGames((all) => ({ ...all, [slug]: { ...gameDrafts[slug] } }))
        setStatus({ kind: 'ok', message: `${slug}.json에 저장했습니다.` })
      }
    } catch {
      setStatus({ kind: 'error', message: '개발 서버에 연결하지 못했습니다.' })
    }
  }

  const revert = () => {
    if (target.kind === 'profile') {
      setProfileDraft({ ...savedProfile })
    } else {
      const slug = target.slug
      setGameDrafts((all) => ({ ...all, [slug]: { ...savedGames[slug] } }))
    }
    setStatus({ kind: 'idle' })
  }

  return (
    <div className={styles.page}>
      <PaletteSwap />

      <h1 className={styles.head}>
        <span className={styles.deco}>►</span> SITE EDITOR
      </h1>
      <p className={styles.sub}>
        배너와 PLAYER 1 소개에 들어가는 내용을 고치고 저장하면 <code>content</code> 폴더의 파일에
        그대로 기록됩니다. 개발 서버에서만 열리는 편집기입니다.
      </p>

      <div className={styles.picker}>
        {games.map((g) => (
          <button
            key={g.slug}
            type="button"
            className={
              target.kind === 'game' && target.slug === g.slug
                ? `${styles.pick} ${styles.pickOn}`
                : styles.pick
            }
            onClick={() => select({ kind: 'game', slug: g.slug })}
          >
            {g.title}
            {changed(gameDrafts[g.slug], savedGames[g.slug]) && <span className={styles.dot}> ●</span>}
          </button>
        ))}
        <button
          type="button"
          className={
            target.kind === 'profile' ? `${styles.pick} ${styles.pickOn}` : styles.pick
          }
          onClick={() => select({ kind: 'profile' })}
        >
          PLAYER 1
          {changed(profileDraft, savedProfile) && <span className={styles.dot}> ●</span>}
        </button>
      </div>

      <div className={styles.cols}>
        <section className={styles.panel}>
          <h2 className={styles.panelTitle}>EDIT</h2>

          {target.kind === 'profile' ? (
            <EditorProfileForm draft={profileDraft} onChange={editProfile} />
          ) : gameDraft ? (
            <EditorGameForm draft={gameDraft} onChange={editGame} />
          ) : (
            <p>편집할 카트리지가 없습니다.</p>
          )}

          <div className={styles.actions}>
            <button className="btn" type="button" onClick={save} disabled={status.kind === 'saving'}>
              {status.kind === 'saving' ? 'SAVING…' : '저장'}
            </button>
            {dirty && (
              <button className="btn not-inserted" type="button" onClick={revert}>
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

          {target.kind === 'profile' ? (
            <Player1
              profile={{
                intro: profileDraft.intro.trim() || '(소개 없음)',
                links: usableLinks(profileDraft.links),
                badges: parseBadges(profileDraft.badges),
              }}
            />
          ) : game && gameDraft ? (
            <div className="carts">
              <Cartridge
                game={{
                  ...game,
                  title: gameDraft.title.trim() || '(제목 없음)',
                  subtitle: gameDraft.subtitle.trim() || undefined,
                  description: gameDraft.description.trim() || '(설명 없음)',
                  tags: parseTags(gameDraft.tags),
                  coverScene: gameDraft.coverScene,
                }}
                index={games.findIndex((g) => g.slug === game.slug)}
                defaultOpen
              />
            </div>
          ) : null}

          <p className={styles.previewNote}>
            실제 화면 그대로입니다. 팔레트를 바꿔 두 테마에서 모두 확인해 보세요.
          </p>
        </section>
      </div>
    </div>
  )
}
