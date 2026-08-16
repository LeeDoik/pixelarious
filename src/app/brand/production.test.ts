import { describe, it, expect } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'

const PAGE = path.join(process.cwd(), 'src', 'app', 'brand', 'page.tsx')

describe('/brand production gate', () => {
  it('keeps the NODE_ENV guard that the deployed site relies on', () => {
    const src = fs.readFileSync(PAGE, 'utf8')
    expect(src).toContain("process.env.NODE_ENV !== 'development'")
    expect(src).toContain('notFound()')
  })

  it('never imports node:fs — the brand renderer must stay client-safe', () => {
    const client = fs.readFileSync(
      path.join(process.cwd(), 'src', 'lib', 'brand.ts'),
      'utf8',
    )
    expect(client).not.toContain('node:fs')
    expect(client).not.toContain('node:path')
  })
})
