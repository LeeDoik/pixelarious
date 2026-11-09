export function Footer() {
  return (
    <footer className="arcade-footer">
      <div className="footer-invitation">
        <div><span className="room-eyebrow">THERE’S ALWAYS ANOTHER ROUND.</span><p>PLAY AGAIN<span>?</span></p></div>
        <a className="arcade-button arcade-button-outline" href="#games">BACK TO THE ARCADE <span aria-hidden="true">↗</span></a>
      </div>
      <div className="footer-bottom">
        <span>© 2026 PIXELARIOUS</span>
        <span><span className="room-led" /> 모든 게임은 무료로 플레이할 수 있습니다</span>
        <a href="#entrance">BACK TO TOP ↑</a>
      </div>
    </footer>
  )
}
