import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { getGames } from '@/lib/games'
import { getProfile } from '@/lib/profile'
import { EditorClient } from '@/components/EditorClient'

export const metadata: Metadata = { title: 'CARTRIDGE EDITOR — NEO_KIDO' }

export default function EditorPage() {
  // Authoring tool: it writes to the repo, so it only exists while developing.
  if (process.env.NODE_ENV !== 'development') notFound()

  return <EditorClient games={getGames()} profile={getProfile()} />
}
