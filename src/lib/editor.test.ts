import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { updateGameRecord } from './editor'

let dir: string

const record = {
  slug: 'test-game',
  order: 10,
  title: 'TEST GAME',
  subtitle: '테스트 게임',
  description: '한 줄짜리 설명.',
  tags: ['GODOT 4', '2D'],
  coverScene: 'starfall',
  playPath: null,
}

function read(file: string) {
  return JSON.parse(fs.readFileSync(path.join(dir, file), 'utf-8'))
}

beforeEach(() => {
  dir = fs.mkdtempSync(path.join(os.tmpdir(), 'neo-kido-editor-'))
  fs.writeFileSync(path.join(dir, '01-test-game.json'), JSON.stringify(record, null, 2) + '\n')
  fs.writeFileSync(
    path.join(dir, '02-other.json'),
    JSON.stringify({ ...record, slug: 'other-game', order: 20, title: 'OTHER' }, null, 2) + '\n',
  )
})

afterEach(() => {
  fs.rmSync(dir, { recursive: true, force: true })
})

describe('updateGameRecord', () => {
  it('saves a multi-line description so newlines survive a round trip', () => {
    const text = '첫 번째 문단입니다.\n\n두 번째 문단입니다.\n마지막 줄.'
    updateGameRecord('test-game', { description: text }, dir)
    expect(read('01-test-game.json').description).toBe(text)
  })

  it('updates title and tags without touching other fields', () => {
    updateGameRecord('test-game', { title: 'NEW TITLE', tags: ['UNITY', '3D'] }, dir)
    const saved = read('01-test-game.json')
    expect(saved.title).toBe('NEW TITLE')
    expect(saved.tags).toEqual(['UNITY', '3D'])
    expect(saved.slug).toBe('test-game')
    expect(saved.order).toBe(10)
    expect(saved.playPath).toBeNull()
  })

  it('removes the subtitle key when given an empty subtitle', () => {
    updateGameRecord('test-game', { subtitle: '' }, dir)
    expect('subtitle' in read('01-test-game.json')).toBe(false)
  })

  it('leaves other game files untouched', () => {
    updateGameRecord('test-game', { title: 'CHANGED' }, dir)
    expect(read('02-other.json').title).toBe('OTHER')
  })

  it('rejects an empty title without writing anything', () => {
    expect(() => updateGameRecord('test-game', { title: '' }, dir)).toThrow(/title/)
    expect(read('01-test-game.json').title).toBe('TEST GAME')
  })

  it('rejects an unknown cover scene', () => {
    expect(() =>
      updateGameRecord('test-game', { coverScene: 'nope' as never }, dir),
    ).toThrow(/coverScene/)
  })

  it('throws for an unknown slug', () => {
    expect(() => updateGameRecord('missing-game', { title: 'X' }, dir)).toThrow(/missing-game/)
  })
})
