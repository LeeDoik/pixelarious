import type { Metadata } from 'next'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { getGame, getGames } from '@/lib/games'
import { PlayFrame } from '@/components/PlayFrame'

export const dynamicParams = false

export function generateStaticParams() {
  return getGames()
    .filter((g) => g.playPath !== null)
    .map((g) => ({ slug: g.slug }))
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>
}): Promise<Metadata> {
  const { slug } = await params
  const game = getGame(slug)
  return { title: game ? `${game.title} — PIXELARIOUS` : 'PIXELARIOUS' }
}

export default async function PlayPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const game = getGame(slug)
  if (!game || !game.playPath) notFound()

  return (
    <div className="play-shell">
      <div className="play-bar">
        <Link className="btn btn-small" href="/">
          ◀ BACK
        </Link>
        <span className="play-title">{game.title}</span>
      </div>
      <PlayFrame slug={game.slug} title={game.title} playPath={game.playPath} />
    </div>
  )
}
