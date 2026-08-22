'use client'

import type { Game } from '@/lib/games'
import { CoverCanvas } from './CoverCanvas'

/**
 * 세로형 카트리지 — 진열장 타일, 팝업 패키지, 삽입 애니메이션이 같은 그림을 쓴다.
 *
 * 실제 카트리지 앞면에 있는 것만 옮겼다:
 *  - 상단 립과 리브 (패미컴/NES 카트 위쪽, 뽑을 때 손이 걸리는 턱)
 *  - 라벨 위쪽 시스템명 바 (NES 라벨의 그 띠)
 *  - 라벨 오른쪽 아래 제품 코드 (NES-XX-USA가 찍히던 자리)
 *  - 삽입 방향 각인과 하단 그립 리브
 * 나사는 넣지 않았다 — 패미컴·NES·게임보이 모두 나사는 뒷면에 있다.
 *
 * children을 주면 라벨 자리(커버 아래)에 그대로 들어간다. 팝업은 이걸로 설명을
 * 카트리지 스티커 위에 인쇄한다 — 옆에 붙은 설명서가 아니라. children이 없으면
 * 제목만 찍힌 순수 장식이라 aria-hidden 처리하고, 접근 가능한 이름은 이 그림을
 * 감싸는 버튼/다이얼로그가 준다.
 */

/** 슬러그 머리글자로 만드는 제품 코드 — PXL-LL-KR 같은 모양 */
export function cartridgeCode(slug: string): string {
  const initials = slug
    .split('-')
    .map((w) => w[0] ?? '')
    .join('')
    .toUpperCase()
    .slice(0, 3)
  return `PXL-${initials}-KR`
}

export function CartridgeArt({
  game,
  size = 'tile',
  children,
}: {
  game: Game
  size?: 'tile' | 'package'
  children?: React.ReactNode
}) {
  return (
    <div
      className={size === 'package' ? 'cartridge cartridge-package' : 'cartridge'}
      aria-hidden={children ? undefined : true}
    >
      <div className="cartridge-lip">
        <span />
        <span />
        <span />
      </div>
      <div className="cartridge-label">
        <div className="label-head">
          <span className="label-chip" />
          <span className="label-sys">PIXELARIOUS</span>
          <span className="label-dots">
            <i />
            <i />
            <i />
          </span>
        </div>
        <CoverCanvas scene={game.coverScene} image={game.coverImage} />
        {children ?? <span className="cartridge-name">{game.title}</span>}
        <span className="label-code">{cartridgeCode(game.slug)}</span>
      </div>
      <div className="cartridge-foot">
        <span className="cartridge-stamp">▼ INSERT THIS SIDE</span>
        <div className="cartridge-grip">
          <span />
          <span />
          <span />
          <span />
        </div>
      </div>
    </div>
  )
}
