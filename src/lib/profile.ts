import fs from 'node:fs'
import path from 'node:path'

export interface ProfileLink {
  label: string
  href: string
}

/** The PLAYER 1 section: who runs the arcade, where to reach them.
 *  donate is optional — with no address the coin slot simply doesn't appear. */
export interface Profile {
  intro: string
  links: ProfileLink[]
  badges: string[]
  donate?: string
}

export const PROFILE_FILE = path.join(process.cwd(), 'content', 'profile.json')

function validate(raw: Record<string, unknown>, file: string): Profile {
  const fail = (msg: string): never => {
    throw new Error(`${path.basename(file)}: ${msg}`)
  }
  const filled = (value: unknown) => typeof value === 'string' && value.trim().length > 0

  if (!filled(raw.intro)) fail('intro required')
  if (!Array.isArray(raw.links)) fail('links must be an array')
  for (const link of raw.links as ProfileLink[]) {
    // A button with nothing behind it is a dead link — reject it here (spec §4.3).
    if (!link || typeof link !== 'object') fail('links must hold {label, href} objects')
    if (!filled(link.label)) fail('every link needs a label')
    if (!filled(link.href)) fail('every link needs an href')
  }
  if (!Array.isArray(raw.badges) || !(raw.badges as unknown[]).every(filled))
    fail('badges must be non-empty strings')
  // Present-but-blank is the dead-button case again: drop the key instead.
  if (raw.donate !== undefined && !filled(raw.donate))
    fail('donate must be a non-empty url, or be left out entirely')

  return raw as unknown as Profile
}

export function getProfile(file: string = PROFILE_FILE): Profile {
  return validate(JSON.parse(fs.readFileSync(file, 'utf-8')), file)
}

/** Applies a patch to the profile and writes it back. Validates before writing,
 *  so a rejected edit leaves the file as it was. */
export function updateProfile(patch: Partial<Profile>, file: string = PROFILE_FILE): Profile {
  const raw = JSON.parse(fs.readFileSync(file, 'utf-8')) as Record<string, unknown>

  const merged: Record<string, unknown> = { ...raw }
  for (const [key, value] of Object.entries(patch)) {
    if (value !== undefined) merged[key] = value
  }

  const profile = validate(merged, file)
  fs.writeFileSync(file, JSON.stringify(merged, null, 2) + '\n', 'utf-8')
  return profile
}
