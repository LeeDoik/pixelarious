'use client'

import { useCallback, useEffect, useState } from 'react'
import type { Game } from '@/lib/games'
import type { Profile } from '@/lib/profile'
import { describeChange, type Change, type DeployResult, type DeployState } from '@/lib/deploy'
import { CartridgeArt } from './CartridgeArt'
import { GameDetail } from './GameDetail'
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

type DeployUi =
  | { kind: 'idle' }
  /** 배포는 되돌리기 어려우니 한 번 더 묻는다 — 두 번째 클릭에서 실제로 푸시한다. */
  | { kind: 'confirm' }
  | { kind: 'pushing' }
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
  const [deployState, setDeployState] = useState<DeployState | null>(null)
  const [deployUi, setDeployUi] = useState<DeployUi>({ kind: 'idle' })

  /** 저장한 내용 중 아직 푸시되지 않은 게 무엇인지 개발 서버에 묻는다. */
  const refreshDeploy = useCallback(async () => {
    try {
      const response = await fetch('/api/deploy')
      if (!response.ok) return
      setDeployState((await response.json()) as DeployState)
    } catch {
      // 배포 상태를 못 읽어도 편집 자체는 계속된다.
    }
  }, [])

  useEffect(() => {
    void refreshDeploy()
  }, [refreshDeploy])

  const select = (next: Target) => {
    setTarget(next)
    setStatus({ kind: 'idle' })
    setDeployUi({ kind: 'idle' })
  }

  const editGame = (patch: Partial<GameDraft>) => {
    if (target.kind !== 'game') return
    const slug = target.slug
    setGameDrafts((all) => ({ ...all, [slug]: { ...all[slug], ...patch } }))
    setStatus({ kind: 'idle' })
    setDeployUi({ kind: 'idle' })
  }

  const editProfile = (patch: Partial<ProfileDraft>) => {
    setProfileDraft((draft) => ({ ...draft, ...patch }))
    setStatus({ kind: 'idle' })
    setDeployUi({ kind: 'idle' })
  }

  const game = target.kind === 'game' ? games.find((g) => g.slug === target.slug) : undefined
  const gameDraft = target.kind === 'game' ? gameDrafts[target.slug] : undefined

  const previewGame =
    game && gameDraft
      ? {
          ...game,
          title: gameDraft.title.trim() || '(제목 없음)',
          subtitle: gameDraft.subtitle.trim() || undefined,
          description: gameDraft.description.trim() || '(설명 없음)',
          tags: parseTags(gameDraft.tags),
          coverScene: gameDraft.coverScene,
        }
      : undefined

  const pending: Change[] = deployState?.changes ?? []
  const unpushed = deployState?.ahead ?? 0
  const deployable = pending.length > 0 || unpushed > 0
  const deploySummary = [
    pending.length > 0 ? `저장한 변경 ${pending.length}개` : null,
    unpushed > 0 ? `푸시 안 한 커밋 ${unpushed}개` : null,
  ]
    .filter(Boolean)
    .join(' · ')

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
        void refreshDeploy()
      } else {
        const slug = target.slug
        setSavedGames((all) => ({ ...all, [slug]: { ...gameDrafts[slug] } }))
        setStatus({ kind: 'ok', message: `${slug}.json에 저장했습니다.` })
        void refreshDeploy()
      }
    } catch {
      setStatus({ kind: 'error', message: '개발 서버에 연결하지 못했습니다.' })
    }
  }

  async function runDeploy() {
    // 첫 클릭은 묻기만 한다. 배포는 공개 사이트를 바꾸니 두 번 눌러야 나간다.
    if (deployUi.kind !== 'confirm') {
      setDeployUi({ kind: 'confirm' })
      return
    }

    setDeployUi({ kind: 'pushing' })
    try {
      const response = await fetch('/api/deploy', { method: 'POST' })
      const data = (await response.json().catch(() => ({}))) as Partial<DeployResult> & {
        error?: string
      }
      if (!response.ok) {
        setDeployUi({ kind: 'error', message: data.error ?? '배포하지 못했습니다.' })
        return
      }
      if (!data.pushed) {
        setDeployUi({ kind: 'ok', message: '배포할 변경이 없었습니다.' })
      } else if (data.sha) {
        setDeployUi({
          kind: 'ok',
          message: `${data.sha} 푸시함 — Vercel이 1~2분 안에 반영합니다.`,
        })
      } else {
        setDeployUi({ kind: 'ok', message: '밀린 커밋을 푸시했습니다.' })
      }
      void refreshDeploy()
    } catch {
      setDeployUi({ kind: 'error', message: '개발 서버에 연결하지 못했습니다.' })
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

          <div className={styles.deploy}>
            <h3 className={styles.deployTitle}>DEPLOY</h3>
            <p className={styles.deployNote}>
              저장한 <code>content</code> 파일을 커밋하고 GitHub에 푸시합니다. 푸시하면 Vercel이
              자동으로 배포합니다.
            </p>

            <div className={styles.actions}>
              <button
                className="btn"
                type="button"
                onClick={runDeploy}
                disabled={deployUi.kind === 'pushing' || !deployable}
              >
                {deployUi.kind === 'pushing'
                  ? 'PUSHING…'
                  : deployUi.kind === 'confirm'
                    ? '정말 배포? 한 번 더'
                    : '배포'}
              </button>
              {deployUi.kind === 'confirm' && (
                <button
                  className="btn not-inserted"
                  type="button"
                  onClick={() => setDeployUi({ kind: 'idle' })}
                >
                  취소
                </button>
              )}
              <span className={styles.status}>
                {deployUi.kind === 'ok' && <span className={styles.ok}>{deployUi.message}</span>}
                {deployUi.kind === 'error' && <span className={styles.err}>{deployUi.message}</span>}
                {(deployUi.kind === 'idle' || deployUi.kind === 'confirm') &&
                  (deployState === null
                    ? '배포 상태를 읽는 중…'
                    : deployable
                      ? `${deployState.branch} — ${deploySummary}`
                      : '푸시할 것이 없습니다')}
              </span>
            </div>

            {pending.length > 0 && (
              <ul className={styles.files}>
                {pending.slice(0, 8).map((change) => (
                  <li key={change.path} className={styles.file}>
                    <span className={styles.fileTag}>{describeChange(change)}</span> {change.path}
                  </li>
                ))}
                {pending.length > 8 && <li className={styles.file}>… 외 {pending.length - 8}개</li>}
              </ul>
            )}

            {dirty && (
              <p className={styles.warn}>
                저장하지 않은 변경은 배포에 들어가지 않습니다. 먼저 저장하세요.
              </p>
            )}
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
          ) : previewGame ? (
            <div className="pkg pkg-preview">
              <CartridgeArt game={previewGame} size="package">
                <GameDetail game={previewGame} titleId={`pkg-title-${previewGame.slug}`} />
              </CartridgeArt>
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
