import fs from 'node:fs'
import path from 'node:path'
import { GAMES_DIR, validate, type Game } from './games'
import type { CoverScene } from './scenes'

/** Fields the editor may change. Slug, order, and playPath are structural — they
 *  decide routing and which files must exist, so they stay read-only here. */
export interface GamePatch {
  title?: string
  subtitle?: string
  description?: string
  tags?: string[]
  coverScene?: CoverScene
}

function findRecordFile(slug: string, dir: string): string {
  const match = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.json'))
    .find((f) => JSON.parse(fs.readFileSync(path.join(dir, f), 'utf-8')).slug === slug)
  if (!match) throw new Error(`no game record found for slug: ${slug}`)
  return match
}

/** Applies a patch to one game record and writes it back. Validates before
 *  writing, so a rejected edit leaves the file as it was. */
export function updateGameRecord(slug: string, patch: GamePatch, dir: string = GAMES_DIR): Game {
  const file = findRecordFile(slug, dir)
  const abs = path.join(dir, file)
  const raw = JSON.parse(fs.readFileSync(abs, 'utf-8')) as Record<string, unknown>

  const merged: Record<string, unknown> = { ...raw }
  for (const [key, value] of Object.entries(patch)) {
    if (value !== undefined) merged[key] = value
  }
  // An empty subtitle means "no subtitle" — drop the key rather than store ''.
  if (typeof merged.subtitle === 'string' && merged.subtitle.trim() === '') delete merged.subtitle

  const game = validate(merged, file)
  fs.writeFileSync(abs, JSON.stringify(merged, null, 2) + '\n', 'utf-8')
  return game
}
