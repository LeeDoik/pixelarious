import { getGameText } from '@/lib/gametext'
import GameTextEditorClient from '@/components/GameTextEditorClient'

/** dev 전용 게임 텍스트 에디터. 프로덕션 가드는 /api/editor가 담당하고,
 *  이 페이지 자체도 프로덕션 빌드에서 노출되면 저장이 404로 거부된다. */
export const dynamic = 'force-dynamic'

export default function GameTextEditorPage() {
  return <GameTextEditorClient initial={getGameText()} />
}
