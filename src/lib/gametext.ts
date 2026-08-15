import fs from 'node:fs'
import path from 'node:path'

/** games-src/it-sleeps-below/src/core/lore.gd 의 SERIES id와 1:1 동기화.
 *  한쪽을 바꾸면 반드시 다른 쪽도 바꾼다. */
export const JOURNAL_IDS: string[] = [
  'han_1', 'baek_1', 'han_2', 'seo_1', 'baek_2',
  'han_3', 'seo_2', 'baek_3', 'seo_3', 'seo_4',
]

export interface TextEntry {
  ko: string
  en: string
}
export type GameText = Record<string, Record<string, TextEntry>>

export const GAMETEXT_PATH = path.join(
  process.cwd(), 'public', 'games', 'it-sleeps-below', 'text', 'text.json',
)

export function validateGameText(raw: unknown): GameText {
  if (typeof raw !== 'object' || raw === null) throw new Error('text.json must be an object')
  const doc = raw as GameText
  for (const [cat, entries] of Object.entries(doc)) {
    if (typeof entries !== 'object' || entries === null) throw new Error(`${cat}: must be an object`)
    for (const [key, entry] of Object.entries(entries)) {
      for (const lang of ['ko', 'en'] as const) {
        if (typeof entry[lang] !== 'string' || entry[lang].trim() === '')
          throw new Error(`${cat}.${key}: ${lang} is missing or empty`)
      }
    }
  }
  if (!doc.journals) throw new Error('journals category required')
  for (const id of JOURNAL_IDS) {
    if (!doc.journals[id]) throw new Error(`journal key missing: ${id}`)
  }
  return doc
}

export function getGameText(): GameText {
  return validateGameText(JSON.parse(fs.readFileSync(GAMETEXT_PATH, 'utf-8')))
}

export function updateGameText(raw: unknown): GameText {
  const doc = validateGameText(raw)
  fs.writeFileSync(GAMETEXT_PATH, JSON.stringify(doc, null, 2) + '\n', 'utf-8')
  return doc
}
