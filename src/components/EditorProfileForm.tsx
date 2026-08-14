'use client'

import type { Profile, ProfileLink } from '@/lib/profile'
import styles from './EditorClient.module.css'

export interface ProfileDraft {
  intro: string
  links: ProfileLink[]
  badges: string
}

export function toProfileDraft(profile: Profile): ProfileDraft {
  return {
    intro: profile.intro,
    links: profile.links.map((link) => ({ ...link })),
    badges: profile.badges.join('\n'),
  }
}

export function parseBadges(value: string): string[] {
  return value
    .split('\n')
    .map((badge) => badge.trim())
    .filter(Boolean)
}

/** Links the visitor can actually follow. Rows missing a label or an href are
 *  dropped rather than shipped as dead buttons (spec §4.3). */
export function usableLinks(links: ProfileLink[]): ProfileLink[] {
  return links
    .map((link) => ({ label: link.label.trim(), href: link.href.trim() }))
    .filter((link) => link.label !== '' && link.href !== '')
}

export function EditorProfileForm({
  draft,
  onChange,
}: {
  draft: ProfileDraft
  onChange: (patch: Partial<ProfileDraft>) => void
}) {
  const setLink = (index: number, patch: Partial<ProfileLink>) => {
    onChange({
      links: draft.links.map((link, i) => (i === index ? { ...link, ...patch } : link)),
    })
  }

  return (
    <>
      <label className={styles.field}>
        <span className={styles.label}>INTRO (소개글)</span>
        <textarea
          className={styles.textarea}
          value={draft.intro}
          onChange={(e) => onChange({ intro: e.target.value })}
        />
        <p className={styles.hint}>
          엔터로 줄을 나누면 소개 상자에도 그대로 나옵니다. 빈 줄을 넣으면 문단이 갈라집니다.
        </p>
      </label>

      <div className={styles.field}>
        <span className={styles.label}>LINKS (버튼)</span>
        {draft.links.length === 0 && <p className={styles.hint}>링크가 없습니다. 버튼 줄이 통째로 숨겨집니다.</p>}
        {draft.links.map((link, index) => (
          <div key={index} className={styles.linkRow}>
            <input
              className={styles.input}
              value={link.label}
              placeholder="GITHUB"
              aria-label={`링크 ${index + 1} 이름`}
              onChange={(e) => setLink(index, { label: e.target.value })}
            />
            <input
              className={styles.input}
              value={link.href}
              placeholder="https://github.com/..."
              aria-label={`링크 ${index + 1} 주소`}
              onChange={(e) => setLink(index, { href: e.target.value })}
            />
            <button
              type="button"
              className={styles.rowBtn}
              aria-label={`링크 ${index + 1} 삭제`}
              onClick={() => onChange({ links: draft.links.filter((_, i) => i !== index) })}
            >
              ✕
            </button>
          </div>
        ))}
        <button
          type="button"
          className={styles.addBtn}
          onClick={() => onChange({ links: [...draft.links, { label: '', href: '' }] })}
        >
          + 링크 추가
        </button>
        <p className={styles.hint}>
          이름과 주소를 모두 채운 링크만 사이트에 나옵니다. 이메일은 <code>mailto:</code>로 시작하세요.
        </p>
      </div>

      <label className={styles.field}>
        <span className={styles.label}>BADGES (한 줄에 하나씩)</span>
        <textarea
          className={styles.badgeArea}
          value={draft.badges}
          onChange={(e) => onChange({ badges: e.target.value })}
        />
      </label>
    </>
  )
}
