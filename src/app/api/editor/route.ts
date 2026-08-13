import { updateGameRecord, type GamePatch } from '@/lib/editor'

/** Writes edits back to content/games/*.json. Development only — the editor is
 *  an authoring tool, so this route must never exist on the deployed site. */
export async function POST(request: Request) {
  if (process.env.NODE_ENV !== 'development') {
    return new Response('Not Found', { status: 404 })
  }

  let body: { slug?: unknown; patch?: unknown }
  try {
    body = await request.json()
  } catch {
    return Response.json({ error: '요청을 읽을 수 없습니다.' }, { status: 400 })
  }

  if (typeof body.slug !== 'string' || typeof body.patch !== 'object' || body.patch === null) {
    return Response.json({ error: 'slug와 patch가 필요합니다.' }, { status: 400 })
  }

  try {
    const game = updateGameRecord(body.slug, body.patch as GamePatch)
    return Response.json({ game })
  } catch (error) {
    return Response.json({ error: (error as Error).message }, { status: 400 })
  }
}
