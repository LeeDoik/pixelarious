import path from 'node:path'
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  // 홈 디렉토리의 떠돌이 package-lock.json 때문에 Next가 워크스페이스 루트를
  // C:\Users\<user>로 잘못 추론해 dev에서 정적 CSS가 404 나는 문제 방지.
  outputFileTracingRoot: path.join(__dirname),
}

export default nextConfig
