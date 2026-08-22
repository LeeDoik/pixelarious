import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { getProfile, updateProfile } from './profile'

let file: string

const profile = {
  intro: '안녕하세요. 한 줄짜리 소개입니다.',
  links: [{ label: 'EMAIL', href: 'mailto:someone@example.com' }],
  badges: ['ENGINE: GODOT 4', 'NEXT: UNITY 3D'],
}

function read() {
  return JSON.parse(fs.readFileSync(file, 'utf-8'))
}

beforeEach(() => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pixelarious-profile-'))
  file = path.join(dir, 'profile.json')
  fs.writeFileSync(file, JSON.stringify(profile, null, 2) + '\n')
})

afterEach(() => {
  fs.rmSync(path.dirname(file), { recursive: true, force: true })
})

describe('profile record', () => {
  it('reads the profile back', () => {
    expect(getProfile(file)).toEqual(profile)
  })

  it('saves a multi-line intro so newlines survive a round trip', () => {
    const intro = '첫 줄입니다.\n\n빈 줄 뒤 둘째 문단.\n마지막 줄.'
    updateProfile({ intro }, file)
    expect(read().intro).toBe(intro)
  })

  it('replaces links and badges', () => {
    updateProfile(
      {
        links: [
          { label: 'GITHUB', href: 'https://github.com/LeeDoik' },
          { label: 'EMAIL', href: 'mailto:lee@example.com' },
        ],
        badges: ['ENGINE: GODOT 4'],
      },
      file,
    )
    const saved = read()
    expect(saved.links).toHaveLength(2)
    expect(saved.links[0]).toEqual({ label: 'GITHUB', href: 'https://github.com/LeeDoik' })
    expect(saved.badges).toEqual(['ENGINE: GODOT 4'])
  })

  it('accepts an empty link list (the section simply hides the row)', () => {
    updateProfile({ links: [] }, file)
    expect(read().links).toEqual([])
  })

  it('rejects a link with no href, so no dead button can ship', () => {
    expect(() => updateProfile({ links: [{ label: 'ITCH.IO', href: '  ' }] }, file)).toThrow(/href/)
    expect(read().links).toEqual(profile.links)
  })

  it('rejects a link with no label', () => {
    expect(() =>
      updateProfile({ links: [{ label: '', href: 'https://example.com' }] }, file),
    ).toThrow(/label/)
  })

  it('rejects an empty intro without writing anything', () => {
    expect(() => updateProfile({ intro: '   ' }, file)).toThrow(/intro/)
    expect(read().intro).toBe(profile.intro)
  })

  it('keeps a donation address on the round trip', () => {
    updateProfile({ donate: 'https://toon.at/donate/pixelarious' }, file)
    expect(read().donate).toBe('https://toon.at/donate/pixelarious')
  })

  it('rejects a blank donation address rather than shipping a dead coin slot', () => {
    expect(() => updateProfile({ donate: '  ' }, file)).toThrow(/donate/)
    expect(read().donate).toBeUndefined()
  })

  it('rejects a blank badge', () => {
    expect(() => updateProfile({ badges: ['OK', ' '] }, file)).toThrow(/badges/)
  })
})
