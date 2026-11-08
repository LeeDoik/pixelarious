import software from '../../content/software.json'
import { getVisibleGames } from './games'
import { COVER_SCENES } from './scenes'
import type { ArcadeProject } from './arcade'

export function getArcadeProjects(): ArcadeProject[] {
  const games: ArcadeProject[] = getVisibleGames().map((game) => ({
    slug: game.slug,
    title: game.title,
    subtitle: game.subtitle,
    description: game.description,
    tags: game.tags,
    kind: 'game',
    coverScene: game.coverScene,
    coverImage: game.coverImage,
    href: game.playPath ? `/play/${game.slug}` : null,
    pcRecommended: game.pcRecommended,
  }))
  const apps = software.map((item): ArcadeProject => {
    const coverScene = COVER_SCENES.find((scene) => scene === item.coverScene)
    if (!coverScene || !item.title || !item.description || !item.href.startsWith('https://')) {
      throw new Error(`Invalid software project: ${item.slug}`)
    }
    return { ...item, coverScene, kind: 'software' }
  })
  const projects = [...games, ...apps]
  if (new Set(projects.map((project) => project.slug)).size !== projects.length) {
    throw new Error('Duplicate arcade project slug')
  }
  return projects
}
