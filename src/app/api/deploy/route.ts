import { deploy, deployState } from '@/lib/deploy-git'

/** 편집기의 배포 버튼. content/ 를 커밋하고 origin 에 푸시하면 Vercel이 빌드한다.
 *  개발 전용 — 배포된 사이트에 이 라우트가 존재하면 안 된다. */

const devOnly = () => process.env.NODE_ENV !== 'development'

export async function GET() {
  if (devOnly()) return new Response('Not Found', { status: 404 })
  try {
    return Response.json(deployState())
  } catch (error) {
    return Response.json({ error: (error as Error).message }, { status: 500 })
  }
}

export async function POST(request: Request) {
  if (devOnly()) return new Response('Not Found', { status: 404 })

  let message: string | undefined
  try {
    const body = (await request.json()) as { message?: unknown }
    if (typeof body.message === 'string') message = body.message
  } catch {
    // 본문 없이 눌러도 된다 — 커밋 메시지는 파일 목록에서 만든다.
  }

  try {
    return Response.json(deploy(message))
  } catch (error) {
    return Response.json({ error: (error as Error).message }, { status: 500 })
  }
}
