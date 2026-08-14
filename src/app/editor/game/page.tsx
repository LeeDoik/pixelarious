import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { getChat } from '@/lib/dialogue'
import { getDocs } from '@/lib/gamedocs'
import { GameEditorClient } from '@/components/GameEditorClient'

export const metadata: Metadata = { title: 'GAME EDITOR — NEO_KIDO' }

export default function GameEditorPage() {
  // 저작 도구: 리포 파일에 기록하므로 개발 중에만 존재한다.
  if (process.env.NODE_ENV !== 'development') notFound()

  return <GameEditorClient chat={getChat()} docs={getDocs()} />
}
