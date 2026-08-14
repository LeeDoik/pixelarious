import { updateGameRecord, type GamePatch } from '@/lib/editor'
import { updateProfile, type Profile } from '@/lib/profile'

/** Writes edits back to content/. Development only — the editor is an authoring
 *  tool, so this route must never exist on the deployed site. */
export async function POST(request: Request) {
  if (process.env.NODE_ENV !== 'development') {
    return new Response('Not Found', { status: 404 })
  }

  let body: { target?: unknown; slug?: unknown; patch?: unknown }
  try {
    body = await request.json()
  } catch {
    return Response.json({ error: '요청을 읽을 수 없습니다.' }, { status: 400 })
  }

  if (typeof body.patch !== 'object' || body.patch === null) {
    return Response.json({ error: 'patch가 필요합니다.' }, { status: 400 })
  }

  try {
    if (body.target === 'profile') {
      return Response.json({ profile: updateProfile(body.patch as Partial<Profile>) })
    }
    if (body.target === 'game') {
      if (typeof body.slug !== 'string') {
        return Response.json({ error: '게임을 저장하려면 slug가 필요합니다.' }, { status: 400 })
      }
      return Response.json({ game: updateGameRecord(body.slug, body.patch as GamePatch) })
    }
    return Response.json({ error: "target은 'game' 또는 'profile'이어야 합니다." }, { status: 400 })
  } catch (error) {
    return Response.json({ error: (error as Error).message }, { status: 400 })
  }
}
