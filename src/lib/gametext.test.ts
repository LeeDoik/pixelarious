import { describe, expect, it } from 'vitest'
import { JOURNAL_IDS, getGameText, validateGameText } from './gametext'

describe('gametext', () => {
  it('loads the real text.json and validates', () => {
    const doc = getGameText()
    expect(Object.keys(doc.journals)).toEqual(expect.arrayContaining(JOURNAL_IDS))
  })

  it('every leaf has non-empty ko and en', () => {
    const doc = getGameText()
    for (const cat of Object.values(doc)) {
      for (const entry of Object.values(cat)) {
        expect(entry.ko.trim().length).toBeGreaterThan(0)
        expect(entry.en.trim().length).toBeGreaterThan(0)
      }
    }
  })

  it('rejects missing journal key', () => {
    const doc = JSON.parse(JSON.stringify(getGameText()))
    delete doc.journals[JOURNAL_IDS[0]]
    expect(() => validateGameText(doc)).toThrow(/journal/)
  })

  it('rejects empty translation', () => {
    const doc = JSON.parse(JSON.stringify(getGameText()))
    doc.ui.tap_to_descend.en = ''
    expect(() => validateGameText(doc)).toThrow(/en/)
  })
})
