export function Footer() {
  return (
    <footer className="arcade-footer">
      <div className="footer-invitation">
        <div><p>PLAY AGAIN<span>?</span></p><span className="footer-note">마음에 드는 자리를 찾았나요?</span></div>
        <a className="arcade-button arcade-button-outline" href="#games">BACK TO THE ARCADE <span aria-hidden="true">↗</span></a>
      </div>
      <div className="footer-bottom">
        <span>© 2026 PIXELARIOUS</span>
        <span>모든 게임은 무료로 플레이할 수 있습니다</span>
        <a href="#entrance">BACK TO TOP ↑</a>
      </div>
    </footer>
  )
}
