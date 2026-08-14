import { describe, expect, it } from 'vitest'
import { applyPatch, validateChat, type ChatData } from './dialogue'
import { applyDocsPatch, type DocsData } from './gamedocs'

const chat: ChatData = {
  start: 'n1',
  nodes: {
    n1: { from: 'seulgi', text: '오빠?', next: 'n2', delay_ms: 1200 },
    n2: {
      from: 'seulgi',
      text: '집이야?',
      choices: [
        { text: '누구세요?', next: 'n3', set: ['met_seulgi'] },
        { text: '(침묵)', next: 'n3' },
      ],
    },
    n3: { from: 'sys', text: '끝' },
  },
  logs: [{ date: '2002-10-05', with: '민규', lines: [{ from: '민규', text: '야' }] }],
}

const docs: DocsData = {
  'doc:essay': { title: '수기.txt', body: '내용' },
}

describe('dialogue applyPatch', () => {
  it('텍스트·딜레이·선택지 문구를 병합하고 구조는 유지한다', () => {
    const { data, errors } = applyPatch(chat, {
      nodes: { n1: { text: '오빠? 왜 켜져 있어', delay_ms: 800, choiceTexts: [] } },
      logs: [{ lines: ['야 어제 왜 안 왔냐'] }],
    })
    expect(errors).toEqual([])
    expect(data.nodes.n1.text).toBe('오빠? 왜 켜져 있어')
    expect(data.nodes.n1.delay_ms).toBe(800)
    expect(data.nodes.n1.next).toBe('n2')
    expect(data.logs[0].lines[0].text).toBe('야 어제 왜 안 왔냐')
    expect(validateChat(data)).toEqual([])
  })

  it('알 수 없는 노드·빈 대사·선택지 수 불일치를 거부한다', () => {
    const { errors } = applyPatch(chat, {
      nodes: {
        ghost: { text: 'x' },
        n1: { text: '   ' },
        n2: { text: '집이야?', choiceTexts: ['하나뿐'] },
      },
      logs: [{ lines: ['야'] }],
    })
    expect(errors.some((e) => e.includes('ghost'))).toBe(true)
    expect(errors.some((e) => e.includes('n1'))).toBe(true)
    expect(errors.some((e) => e.includes('선택지 수'))).toBe(true)
  })

  it('로그 구조가 다르면 거부한다', () => {
    const { errors } = applyPatch(chat, { nodes: {}, logs: [] })
    expect(errors.some((e) => e.includes('로그 수'))).toBe(true)
  })
})

describe('gamedocs applyDocsPatch', () => {
  it('제목과 본문을 병합한다', () => {
    const { data, errors } = applyDocsPatch(docs, {
      'doc:essay': { title: '낙방 수기.txt', body: '고친 내용' },
    })
    expect(errors).toEqual([])
    expect(data['doc:essay'].title).toBe('낙방 수기.txt')
  })

  it('없는 문서와 빈 내용을 거부한다', () => {
    const { errors } = applyDocsPatch(docs, {
      'doc:ghost': { title: 'x', body: 'y' },
      'doc:essay': { title: '', body: 'y' },
    })
    expect(errors.length).toBe(2)
  })
})
