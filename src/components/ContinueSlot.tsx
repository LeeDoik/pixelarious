/**
 * 라인업의 마지막 칸. EMPTY SLOT이 "다음 게임이 아직 비어 있다"고 말한 바로 다음에
 * 놓여서, 계속 돌리려면 코인이 필요하다는 아케이드의 규칙으로 후원을 설명한다.
 * 후원 주소가 없으면 아무것도 그리지 않는다 — 갈 곳 없는 칸은 만들지 않는다.
 */
export function ContinueSlot({ href, index }: { href?: string; index: number }) {
  if (!href) return null

  return (
    <a
      className="cart credit"
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      aria-label="후원하기 — 투네이션으로 이동"
    >
      <div className="cart-strip">
        <span className="cart-no">{String(index + 1).padStart(2, '0')}</span>
        <div className="credit-box">
          <span className="credit-count" aria-hidden>
            9
          </span>
          <span className="credit-slot" aria-hidden>
            <span className="credit-slit" />
          </span>
          <span className="credit-disc" aria-hidden />
        </div>
        <h3 className="cart-title">
          CONTINUE?<span className="kr">이 아케이드를 계속 돌리기</span>
        </h3>
        <span className="cart-hint">INSERT COIN ▸</span>
      </div>
    </a>
  )
}
