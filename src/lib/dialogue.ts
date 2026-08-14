import fs from 'node:fs'
import path from 'node:path'

/** 게임 대화 데이터(game/content/chat.json)의 대사 편집 계층.
 *  편집기는 텍스트·딜레이만 패치로 보내고, 분기 구조(id·next·require·set)는
 *  디스크의 원본을 그대로 유지한다 — 스토리 로직이 편집기로는 깨질 수 없다. */

const CHAT_PATH = path.join(process.cwd(), 'game', 'content', 'chat.json')

export type ChatChoice = { text: string; next: string; set?: string[] }
export type ChatNode = {
  from: string
  text: string
  next?: string
  choices?: ChatChoice[]
  require?: string
  set?: string[]
  delay_ms?: number
}
export type ChatLogLine = { from: string; text: string }
export type ChatLog = { date: string; with: string; lines: ChatLogLine[] }
export type ChatData = { start: string; nodes: Record<string, ChatNode>; logs: ChatLog[] }

export type NodePatch = { text: string; delay_ms?: number; choiceTexts?: string[] }
export type DialoguePatch = {
  nodes: Record<string, NodePatch>
  /** 로그는 구조 고정 — 인덱스가 디스크의 로그/줄과 1:1 대응해야 한다 */
  logs: { lines: string[] }[]
}

export function getChat(): ChatData {
  return JSON.parse(fs.readFileSync(CHAT_PATH, 'utf-8')) as ChatData
}

/** 패치를 원본에 병합. 실패 사유가 있으면 errors에 담고 원본은 건드리지 않는다. */
export function applyPatch(data: ChatData, patch: DialoguePatch): { data: ChatData; errors: string[] } {
  const errors: string[] = []
  const next: ChatData = structuredClone(data)

  for (const [id, p] of Object.entries(patch.nodes ?? {})) {
    const node = next.nodes[id]
    if (!node) {
      errors.push(`알 수 없는 노드: ${id}`)
      continue
    }
    if (typeof p.text !== 'string' || p.text.trim() === '') {
      errors.push(`${id}: 대사가 비어 있습니다`)
      continue
    }
    node.text = p.text
    if (p.delay_ms !== undefined) {
      if (!Number.isFinite(p.delay_ms) || p.delay_ms < 0) {
        errors.push(`${id}: delay_ms는 0 이상의 숫자여야 합니다`)
      } else {
        node.delay_ms = Math.round(p.delay_ms)
      }
    }
    if (p.choiceTexts !== undefined) {
      const choices = node.choices ?? []
      if (p.choiceTexts.length !== choices.length) {
        errors.push(`${id}: 선택지 수가 원본(${choices.length}개)과 다릅니다`)
        continue
      }
      p.choiceTexts.forEach((t, i) => {
        if (typeof t !== 'string' || t.trim() === '') {
          errors.push(`${id}: ${i + 1}번 선택지가 비어 있습니다`)
        } else {
          choices[i].text = t
        }
      })
    }
  }

  const logPatches = patch.logs ?? []
  if (logPatches.length !== next.logs.length) {
    errors.push(`로그 수가 원본(${next.logs.length}개)과 다릅니다`)
  } else {
    logPatches.forEach((lp, li) => {
      const log = next.logs[li]
      if (lp.lines.length !== log.lines.length) {
        errors.push(`로그 ${log.date}: 줄 수가 원본(${log.lines.length}줄)과 다릅니다`)
        return
      }
      lp.lines.forEach((t, i) => {
        if (typeof t !== 'string' || t.trim() === '') {
          errors.push(`로그 ${log.date}: ${i + 1}번째 줄이 비어 있습니다`)
        } else {
          log.lines[i].text = t
        }
      })
    })
  }

  return { data: next, errors }
}

/** 병합 결과가 게임 로더(ContentDB) 규칙을 여전히 만족하는지 최종 확인 */
export function validateChat(data: ChatData): string[] {
  const errors: string[] = []
  if (!data.nodes[data.start]) errors.push(`시작 노드(${data.start})가 없습니다`)
  for (const [id, node] of Object.entries(data.nodes)) {
    if (node.next && !data.nodes[node.next]) errors.push(`${id} → 없는 노드 ${node.next}`)
    for (const c of node.choices ?? []) {
      if (!data.nodes[c.next]) errors.push(`${id} 선택지 → 없는 노드 ${c.next}`)
    }
  }
  return errors
}

export function updateChat(patch: DialoguePatch): ChatData {
  const { data, errors } = applyPatch(getChat(), patch)
  const structural = validateChat(data)
  const all = [...errors, ...structural]
  if (all.length > 0) throw new Error(all.join(' / '))
  fs.writeFileSync(CHAT_PATH, JSON.stringify(data, null, 1) + '\n', 'utf-8')
  return data
}
