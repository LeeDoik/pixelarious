'use client'

import { useMemo, useState } from 'react'
import type { ChatData } from '@/lib/dialogue'
import type { DocsData } from '@/lib/gamedocs'
import { PaletteSwap } from './PaletteSwap'
import styles from './GameEditorClient.module.css'

type Tab = 'dialogue' | 'logs' | 'docs'

type Status =
  | { kind: 'idle' }
  | { kind: 'saving' }
  | { kind: 'ok'; message: string }
  | { kind: 'error'; message: string }

type NodeDraft = { text: string; delay: string; choiceTexts: string[] }
type LogDraft = string[]

const changed = (a: unknown, b: unknown) => JSON.stringify(a) !== JSON.stringify(b)

const rowsFor = (text: string) =>
  Math.max(2, Math.min(14, text.split('\n').length + Math.floor(text.length / 60)))

function toNodeDrafts(chat: ChatData): Record<string, NodeDraft> {
  return Object.fromEntries(
    Object.entries(chat.nodes).map(([id, n]) => [
      id,
      {
        text: n.text,
        delay: n.delay_ms !== undefined ? String(n.delay_ms) : '',
        choiceTexts: (n.choices ?? []).map((c) => c.text),
      },
    ]),
  )
}

function toLogDrafts(chat: ChatData): LogDraft[] {
  return chat.logs.map((log) => log.lines.map((l) => l.text))
}

function toDocDrafts(docs: DocsData): Record<string, { title: string; body: string }> {
  return Object.fromEntries(Object.entries(docs).map(([cid, d]) => [cid, { ...d }]))
}

export function GameEditorClient({ chat, docs }: { chat: ChatData; docs: DocsData }) {
  const [tab, setTab] = useState<Tab>('dialogue')
  const [savedNodes, setSavedNodes] = useState(() => toNodeDrafts(chat))
  const [nodeDrafts, setNodeDrafts] = useState(() => toNodeDrafts(chat))
  const [savedLogs, setSavedLogs] = useState(() => toLogDrafts(chat))
  const [logDrafts, setLogDrafts] = useState(() => toLogDrafts(chat))
  const [savedDocs, setSavedDocs] = useState(() => toDocDrafts(docs))
  const [docDrafts, setDocDrafts] = useState(() => toDocDrafts(docs))
  const [selectedDoc, setSelectedDoc] = useState(() => Object.keys(docs)[0] ?? '')
  const [status, setStatus] = useState<Status>({ kind: 'idle' })

  const nodeIds = useMemo(() => Object.keys(chat.nodes), [chat])
  const docIds = useMemo(() => Object.keys(docs), [docs])

  const chatDirty = changed(nodeDrafts, savedNodes) || changed(logDrafts, savedLogs)
  const docsDirty = changed(docDrafts, savedDocs)

  const editNode = (id: string, patch: Partial<NodeDraft>) => {
    setNodeDrafts((all) => ({ ...all, [id]: { ...all[id], ...patch } }))
    setStatus({ kind: 'idle' })
  }

  const editChoice = (id: string, index: number, text: string) => {
    setNodeDrafts((all) => {
      const next = [...all[id].choiceTexts]
      next[index] = text
      return { ...all, [id]: { ...all[id], choiceTexts: next } }
    })
    setStatus({ kind: 'idle' })
  }

  const editLogLine = (logIndex: number, lineIndex: number, text: string) => {
    setLogDrafts((all) =>
      all.map((lines, i) =>
        i === logIndex ? lines.map((l, j) => (j === lineIndex ? text : l)) : lines,
      ),
    )
    setStatus({ kind: 'idle' })
  }

  const editDoc = (cid: string, patch: Partial<{ title: string; body: string }>) => {
    setDocDrafts((all) => ({ ...all, [cid]: { ...all[cid], ...patch } }))
    setStatus({ kind: 'idle' })
  }

  async function saveChat() {
    setStatus({ kind: 'saving' })
    const patch = {
      nodes: Object.fromEntries(
        nodeIds.map((id) => {
          const d = nodeDrafts[id]
          const delay = d.delay.trim() === '' ? undefined : Number(d.delay)
          return [id, { text: d.text, delay_ms: delay, choiceTexts: d.choiceTexts }]
        }),
      ),
      logs: logDrafts.map((lines) => ({ lines })),
    }
    await post({ target: 'dialogue', patch }, () => {
      setSavedNodes(structuredClone(nodeDrafts))
      setSavedLogs(structuredClone(logDrafts))
      setStatus({ kind: 'ok', message: 'chat.json에 저장했습니다.' })
    })
  }

  async function saveDocs() {
    setStatus({ kind: 'saving' })
    await post({ target: 'docs', patch: docDrafts }, () => {
      setSavedDocs(structuredClone(docDrafts))
      setStatus({ kind: 'ok', message: 'docs.json에 저장했습니다.' })
    })
  }

  async function post(body: unknown, onOk: () => void) {
    try {
      const response = await fetch('/api/game-editor', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
      const data = await response.json().catch(() => ({}))
      if (!response.ok) {
        setStatus({ kind: 'error', message: data.error ?? '저장하지 못했습니다.' })
        return
      }
      onOk()
    } catch {
      setStatus({ kind: 'error', message: '개발 서버에 연결하지 못했습니다.' })
    }
  }

  const revert = () => {
    if (tab === 'docs') {
      setDocDrafts(structuredClone(savedDocs))
    } else {
      setNodeDrafts(structuredClone(savedNodes))
      setLogDrafts(structuredClone(savedLogs))
    }
    setStatus({ kind: 'idle' })
  }

  const dirty = tab === 'docs' ? docsDirty : chatDirty
  const save = tab === 'docs' ? saveDocs : saveChat

  const speakerClass = (from: string) =>
    from === 'seulgi'
      ? `${styles.speaker} ${styles.speakerSeulgi}`
      : from === 'player'
        ? `${styles.speaker} ${styles.speakerPlayer}`
        : styles.speaker

  const speakerName = (from: string) =>
    from === 'seulgi' ? '슬기' : from === 'player' ? '나' : '시스템'

  return (
    <div className={styles.page}>
      <PaletteSwap />

      <h1 className={styles.head}>
        <span className={styles.deco}>►</span> GAME EDITOR
      </h1>
      <p className={styles.sub}>
        LAST LOGIN의 대사와 게임 내 문서를 고치는 편집기입니다. 저장하면{' '}
        <code>games-src/last-login/content/</code>의 파일에 그대로 기록됩니다. 분기 구조(노드 연결·플래그)는
        여기서 바뀌지 않아 스토리 로직이 깨질 걱정 없이 문장만 다듬을 수 있습니다.
      </p>
      <p className={styles.notice}>
        저장 = 원본 데이터 수정. 실제 게임(웹 빌드)에 반영하려면 에이전트 세션에서{' '}
        <strong>&quot;대사 반영해줘&quot;</strong>라고 요청하세요 (재익스포트 + 배포).
      </p>

      <div className={styles.tabs}>
        <button
          type="button"
          className={tab === 'dialogue' ? `${styles.tab} ${styles.tabOn}` : styles.tab}
          onClick={() => setTab('dialogue')}
        >
          슬기 대화{chatDirty && <span className={styles.dot}> ●</span>}
        </button>
        <button
          type="button"
          className={tab === 'logs' ? `${styles.tab} ${styles.tabOn}` : styles.tab}
          onClick={() => setTab('logs')}
        >
          지난 대화 로그
        </button>
        <button
          type="button"
          className={tab === 'docs' ? `${styles.tab} ${styles.tabOn}` : styles.tab}
          onClick={() => setTab('docs')}
        >
          게임 내 파일{docsDirty && <span className={styles.dot}> ●</span>}
        </button>
      </div>

      {tab === 'dialogue' && (
        <section className={styles.panel}>
          {nodeIds.map((id) => {
            const node = chat.nodes[id]
            const draft = nodeDrafts[id]
            return (
              <div key={id} className={styles.nodeCard}>
                <div className={styles.nodeMeta}>
                  <span>{id}</span>
                  <span className={speakerClass(node.from)}>{speakerName(node.from)}</span>
                  {node.require && <span>잠금: {node.require}</span>}
                  {node.set && node.set.length > 0 && <span>설정: {node.set.join(', ')}</span>}
                  {node.next && <span>→ {node.next}</span>}
                </div>
                <textarea
                  className={styles.field}
                  rows={rowsFor(draft.text)}
                  value={draft.text}
                  onChange={(e) => editNode(id, { text: e.target.value })}
                />
                {node.next && (
                  <div className={styles.row}>
                    <span className={styles.small}>표시 간격(ms)</span>
                    <input
                      className={styles.delay}
                      value={draft.delay}
                      placeholder="900"
                      onChange={(e) => editNode(id, { delay: e.target.value })}
                    />
                  </div>
                )}
                {draft.choiceTexts.map((t, i) => (
                  <div key={i} className={styles.row}>
                    <span className={styles.small}>선택지 → {node.choices?.[i]?.next}</span>
                    <textarea
                      className={styles.field}
                      rows={1}
                      value={t}
                      onChange={(e) => editChoice(id, i, e.target.value)}
                    />
                  </div>
                ))}
              </div>
            )
          })}
        </section>
      )}

      {tab === 'logs' && (
        <section className={styles.panel}>
          {chat.logs.map((log, li) => (
            <div key={log.date} className={styles.nodeCard}>
              <div className={styles.nodeMeta}>
                <span>
                  [{log.date}] {log.with}
                </span>
              </div>
              {log.lines.map((line, i) => (
                <div key={i} className={styles.row}>
                  <span className={styles.small}>{line.from}</span>
                  <textarea
                    className={styles.field}
                    rows={1}
                    value={logDrafts[li][i]}
                    onChange={(e) => editLogLine(li, i, e.target.value)}
                  />
                </div>
              ))}
            </div>
          ))}
        </section>
      )}

      {tab === 'docs' && (
        <div className={styles.cols}>
          <div className={styles.list}>
            {docIds.map((cid) => (
              <button
                key={cid}
                type="button"
                className={cid === selectedDoc ? `${styles.item} ${styles.itemOn}` : styles.item}
                onClick={() => setSelectedDoc(cid)}
              >
                {docDrafts[cid].title}
                {changed(docDrafts[cid], savedDocs[cid]) && <span className={styles.dot}> ●</span>}
              </button>
            ))}
          </div>
          <section className={styles.panel}>
            {selectedDoc && docDrafts[selectedDoc] ? (
              <>
                <div className={styles.nodeMeta}>
                  <span>{selectedDoc}</span>
                </div>
                <div className={styles.row}>
                  <span className={styles.small}>파일 이름</span>
                  <input
                    className={styles.field}
                    value={docDrafts[selectedDoc].title}
                    onChange={(e) => editDoc(selectedDoc, { title: e.target.value })}
                  />
                </div>
                <div className={styles.row}>
                  <span className={styles.small}>내용</span>
                </div>
                <textarea
                  className={styles.field}
                  rows={rowsFor(docDrafts[selectedDoc].body)}
                  value={docDrafts[selectedDoc].body}
                  onChange={(e) => editDoc(selectedDoc, { body: e.target.value })}
                />
              </>
            ) : (
              <p>편집할 문서가 없습니다.</p>
            )}
          </section>
        </div>
      )}

      <div className={styles.actions}>
        <button className="btn" type="button" onClick={save} disabled={status.kind === 'saving'}>
          {status.kind === 'saving' ? 'SAVING…' : '저장'}
        </button>
        {dirty && (
          <button className="btn not-inserted" type="button" onClick={revert}>
            되돌리기
          </button>
        )}
        <span>
          {status.kind === 'ok' && <span className={styles.ok}>{status.message}</span>}
          {status.kind === 'error' && <span className={styles.err}>{status.message}</span>}
          {status.kind === 'idle' && dirty && (
            <span className={styles.dirty}>저장하지 않은 변경이 있습니다</span>
          )}
        </span>
      </div>
    </div>
  )
}
