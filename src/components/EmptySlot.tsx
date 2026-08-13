export function EmptySlot({ index }: { index: number }) {
  return (
    <article className="cart soon">
      <div className="cart-strip">
        <span className="cart-no">{String(index + 1).padStart(2, '0')}</span>
        <div className="slot-box">EMPTY SLOT</div>
        <h3 className="cart-title">
          NEW GAME +<span className="kr">다음 게임 제작 중…</span>
        </h3>
        <span className="cart-hint"></span>
      </div>
      <div className="cart-detail">
        <div></div>
      </div>
    </article>
  )
}
