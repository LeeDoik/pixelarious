import fs from 'node:fs'
import path from 'node:path'
import { COVER_SCENES, type CoverScene } from './scenes'

export interface Game {
  slug: string
  order: number
  title: string
  subtitle?: string
  description: string
  tags: string[]
  coverScene: CoverScene
  coverImage?: string
  playPath: string | null
  /** Keeps the cartridge out of the public lineup. The record and its /play
   *  route stay intact — this only hides it from the listing. */
  hidden?: boolean
}

export const GAMES_DIR = path.join(process.cwd(), 'content', 'games')

export function validate(raw: Record<string, unknown>, file: string): Game {
  const fail = (msg: string): never => {
    throw new Error(`${file}: ${msg}`)
  }
  if (typeof raw.slug !== 'string' || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(raw.slug))
    fail('slug must be kebab-case')
  if (typeof raw.order !== 'number') fail('order must be a number')
  if (typeof raw.title !== 'string' || raw.title.length === 0) fail('title required')
  if (raw.subtitle !== undefined && typeof raw.subtitle !== 'string') fail('subtitle must be a string')
  if (typeof raw.description !== 'string' || raw.description.length === 0) fail('description required')
  if (!Array.isArray(raw.tags) || raw.tags.some((t) => typeof t !== 'string')) fail('tags must be string[]')
  if (!COVER_SCENES.includes(raw.coverScene as CoverScene))
    fail(`coverScene must be one of: ${COVER_SCENES.join(', ')}`)
  if (raw.coverImage !== undefined && typeof raw.coverImage !== 'string')
    fail('coverImage must be a string')
  if (typeof raw.coverImage === 'string') {
    const absImg = path.join(process.cwd(), 'public', raw.coverImage)
    if (!fs.existsSync(absImg)) fail(`coverImage file missing: ${raw.coverImage}`)
  }
  if (raw.playPath !== null && typeof raw.playPath !== 'string') fail('playPath must be string or null')
  if (typeof raw.playPath === 'string') {
    const abs = path.join(process.cwd(), 'public', raw.playPath)
    if (!fs.existsSync(abs)) fail(`playPath file missing: ${raw.playPath}`)
  }
  if (raw.hidden !== undefined && typeof raw.hidden !== 'boolean') fail('hidden must be a boolean')
  return raw as unknown as Game
}

export function getGames(): Game[] {
  const files = fs.readdirSync(GAMES_DIR).filter((f) => f.endsWith('.json'))
  const games = files.map((f) =>
    validate(JSON.parse(fs.readFileSync(path.join(GAMES_DIR, f), 'utf-8')), f),
  )
  const seen = new Set<string>()
  for (const g of games) {
    if (seen.has(g.slug)) throw new Error(`duplicate slug: ${g.slug}`)
    seen.add(g.slug)
  }
  return games.sort((a, b) => a.order - b.order)
}

/** The lineup the site shows. Hidden cartridges stay in the registry — the
 *  editor and /play still see them — they just drop out of the listing. */
export function getVisibleGames(): Game[] {
  return getGames().filter((g) => !g.hidden)
}

export function getGame(slug: string): Game | undefined {
  return getGames().find((g) => g.slug === slug)
}
