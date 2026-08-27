import { describe, it, expect, afterEach } from 'vitest'
import { render, cleanup } from '@testing-library/react'
import { Player1 } from './Player1'
import type { Profile } from '@/lib/profile'

afterEach(cleanup)

const profile = (intro: string): Profile => ({
  intro,
  links: [{ label: 'EMAIL', href: 'mailto:me@example.com' }],
  badges: ['ENGINE: GODOT 4'],
})

describe('Player1', () => {
  it('splits the intro on blank lines so the card fills both columns', () => {
    const { container } = render(<Player1 profile={profile('한국어 소개\n두 번째 줄\n\nEnglish intro')} />)
    const paragraphs = [...container.querySelectorAll('.about p')].map((p) => p.textContent)
    expect(paragraphs).toEqual(['한국어 소개\n두 번째 줄', 'English intro'])
  })

  it('keeps a single-paragraph intro in one block', () => {
    const { container } = render(<Player1 profile={profile('한 문단짜리 소개')} />)
    expect(container.querySelectorAll('.about p')).toHaveLength(1)
  })
})
