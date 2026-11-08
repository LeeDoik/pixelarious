import { expect, it } from 'vitest'
import { getArcadeProjects } from './projects'
import { getVisibleGames } from './games'

it('keeps the public game registry as the source of arcade metadata and playable routes', () => {
  const projects = getArcadeProjects()
  const publicGames = getVisibleGames()
  expect(projects.filter((project) => project.kind === 'game').map((project) => project.slug)).toEqual(publicGames.map((game) => game.slug))
  for (const game of publicGames) {
    const station = projects.find((project) => project.slug === game.slug)
    expect(station?.title).toBe(game.title)
    expect(station?.description).toBe(game.description)
    expect(station?.href).toBe(game.playPath ? `/play/${game.slug}` : null)
  }
  expect(projects.some((project) => project.slug === 'system-check')).toBe(false)
  expect(projects.find((project) => project.kind === 'software')?.href).toBe('https://github.com/LeeDoik/pixelarious/tree/master/extension')
})
