import { describe, it, expect } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'

/**
 * 게이트 자체의 동작은 page.test.tsx가 BrandPage()를 직접 호출해 검증한다.
 * 여기서는 그것으로 잡히지 않는 것 하나만 본다 — 브랜드 렌더러에 Node 내장 모듈이
 * 섞여 들어가는 것. 클라이언트 컴포넌트가 이 모듈을 import하므로 섞이면 빌드가 깨지지만,
 * 깨지기 전에 알려주는 편이 낫다.
 */
const BRAND = path.join(process.cwd(), 'src', 'lib', 'brand.ts')

// import/export 구문의 모듈 지정자만 본다. 주석에 'node:fs'를 적어도 걸리지 않고,
// 접두사 없는 'fs'/'path' 형태도 잡는다.
const NODE_BUILTIN = /\bfrom\s+['"](?:node:)?(?:fs|path|os|crypto|child_process)['"]/

describe('brand renderer stays client-safe', () => {
  it('imports no Node builtin — a client component renders it', () => {
    const src = fs.readFileSync(BRAND, 'utf8')
    const match = src.match(NODE_BUILTIN)
    expect(match?.[0] ?? null).toBeNull()
  })

  it('flags a Node builtin import regardless of quote style or node: prefix', () => {
    for (const line of [
      "import fs from 'node:fs'",
      'import fs from "fs"',
      "export { join } from 'node:path'",
      'import { randomUUID } from "node:crypto"',
    ]) {
      expect(NODE_BUILTIN.test(line), line).toBe(true)
    }
    // 주석이나 문자열 안의 언급은 오탐이 되면 안 된다
    for (const line of ["// never import node:fs here", "const msg = 'node:path'"]) {
      expect(NODE_BUILTIN.test(line), line).toBe(false)
    }
  })
})
