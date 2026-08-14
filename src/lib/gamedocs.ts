import fs from 'node:fs'
import path from 'node:path'

/** 게임 내 파일(문서) 편집 계층 — game/content/docs.json.
 *  문서 id(cid)는 fs.json·기록물 목록이 참조하므로 고정하고, 제목·본문만 수정한다. */

const DOCS_PATH = path.join(process.cwd(), 'game', 'content', 'docs.json')

export type GameDoc = { title: string; body: string }
export type DocsData = Record<string, GameDoc>
export type DocsPatch = Record<string, GameDoc>

export function getDocs(): DocsData {
  return JSON.parse(fs.readFileSync(DOCS_PATH, 'utf-8')) as DocsData
}

export function applyDocsPatch(data: DocsData, patch: DocsPatch): { data: DocsData; errors: string[] } {
  const errors: string[] = []
  const next: DocsData = structuredClone(data)
  for (const [cid, doc] of Object.entries(patch ?? {})) {
    if (!next[cid]) {
      errors.push(`알 수 없는 문서: ${cid}`)
      continue
    }
    if (typeof doc.title !== 'string' || doc.title.trim() === '') {
      errors.push(`${cid}: 제목이 비어 있습니다`)
      continue
    }
    if (typeof doc.body !== 'string' || doc.body.trim() === '') {
      errors.push(`${cid}: 본문이 비어 있습니다`)
      continue
    }
    next[cid] = { title: doc.title, body: doc.body }
  }
  return { data: next, errors }
}

export function updateDocs(patch: DocsPatch): DocsData {
  const { data, errors } = applyDocsPatch(getDocs(), patch)
  if (errors.length > 0) throw new Error(errors.join(' / '))
  fs.writeFileSync(DOCS_PATH, JSON.stringify(data, null, 1) + '\n', 'utf-8')
  return data
}
