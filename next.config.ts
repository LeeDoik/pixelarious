import path from 'node:path'
import type { NextConfig } from 'next'

// 프레임 차단 헤더(X-Frame-Options / CSP frame-ancestors)를 추가하지 말 것.
// 크롬 사이드 패널 확장(extension/starfall-drift/)이 /games/starfall-drift/index.html을
// iframe으로 띄운다 — 헤더가 붙으면 확장에서 게임이 통째로 뜨지 않는다.
// 꼭 필요하면 frame-ancestors에 chrome-extension://<확장 ID>를 허용 목록으로 넣는다.
const nextConfig: NextConfig = {
  // 홈 디렉토리의 떠돌이 package-lock.json 때문에 Next가 워크스페이스 루트를
  // C:\Users\<user>로 잘못 추론해 dev에서 정적 CSS가 404 나는 문제 방지.
  outputFileTracingRoot: path.join(__dirname),
}

export default nextConfig
