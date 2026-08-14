import { updateChat, type DialoguePatch } from '@/lib/dialogue'
import { updateDocs, type DocsPatch } from '@/lib/gamedocs'

/** 게임 콘텐츠(대화·문서) 편집 저장. 개발 전용 — 배포 사이트에는 존재하지 않는다.
 *  저장 후 게임 반영은 웹 익스포트 재실행이 필요하다(에이전트 세션에 요청). */
export async function POST(request: Request) {
  if (process.env.NODE_ENV !== 'development') {
    return new Response('Not Found', { status: 404 })
  }

  let body: { target?: unknown; patch?: unknown }
  try {
    body = await request.json()
  } catch {
    return Response.json({ error: '요청을 읽을 수 없습니다.' }, { status: 400 })
  }

  if (typeof body.patch !== 'object' || body.patch === null) {
    return Response.json({ error: 'patch가 필요합니다.' }, { status: 400 })
  }

  try {
    if (body.target === 'dialogue') {
      return Response.json({ chat: updateChat(body.patch as DialoguePatch) })
    }
    if (body.target === 'docs') {
      return Response.json({ docs: updateDocs(body.patch as DocsPatch) })
    }
    return Response.json({ error: "target은 'dialogue' 또는 'docs'여야 합니다." }, { status: 400 })
  } catch (error) {
    return Response.json({ error: (error as Error).message }, { status: 400 })
  }
}
