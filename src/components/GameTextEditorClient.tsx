'use client'
import { useMemo, useState } from 'react'
import type { GameText } from '@/lib/gametext'

/** 카테고리별 목록 + KO/EN 나란히 편집. 저장은 전체 문서 POST — 서버가 검증한다. */
export default function GameTextEditorClient({ initial }: { initial: GameText }) {
  const [doc, setDoc] = useState<GameText>(initial)
  const [cat, setCat] = useState<string>(Object.keys(initial)[0])
  const [status, setStatus] = useState<string>('')
  const keys = useMemo(() => Object.keys(doc[cat] ?? {}), [doc, cat])

  const edit = (key: string, lang: 'ko' | 'en', value: string) =>
    setDoc((d) => ({ ...d, [cat]: { ...d[cat], [key]: { ...d[cat][key], [lang]: value } } }))

  const save = async () => {
    setStatus('저장 중…')
    const res = await fetch('/api/editor', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ target: 'gametext', patch: doc }),
    })
    const body = await res.json()
    setStatus(res.ok ? '저장됨' : `오류: ${body.error}`)
  }

  return (
    <main style={{ padding: 24, fontFamily: 'monospace', maxWidth: 960, margin: '0 auto' }}>
      <h1>IT SLEEPS BELOW — 텍스트 에디터</h1>
      <nav style={{ display: 'flex', gap: 8, margin: '16px 0' }}>
        {Object.keys(doc).map((c) => (
          <button key={c} onClick={() => setCat(c)} disabled={c === cat}>{c}</button>
        ))}
      </nav>
      {keys.map((key) => (
        <fieldset key={key} style={{ marginBottom: 12 }}>
          <legend>{key}</legend>
          <textarea rows={4} style={{ width: '48%' }} value={doc[cat][key].ko}
            onChange={(e) => edit(key, 'ko', e.target.value)} />
          <textarea rows={4} style={{ width: '48%', float: 'right' }} value={doc[cat][key].en}
            onChange={(e) => edit(key, 'en', e.target.value)} />
        </fieldset>
      ))}
      <button onClick={save}>저장</button> <span>{status}</span>
    </main>
  )
}
