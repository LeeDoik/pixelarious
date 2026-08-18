import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { getGames } from '@/lib/games'
import { BrandClient } from '@/components/BrandClient'

export const metadata: Metadata = { title: 'BRAND ASSETS — PIXELARIOUS' }

export default function BrandPage() {
  // 브랜드 자산 제작 도구다. 배포된 사이트에는 존재하지 않는다 (스펙 §7).
  if (process.env.NODE_ENV !== 'development') notFound()

  return <BrandClient games={getGames()} />
}
