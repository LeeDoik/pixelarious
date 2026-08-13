const LINKS: { label: string; href: string }[] = [
  { label: 'EMAIL', href: 'mailto:lee253628@gmail.com' },
  // 준비되면 주석 해제 (죽은 링크 금지 — 스펙 §4.3):
  // { label: 'GITHUB', href: 'https://github.com/<계정>' },
  // { label: 'ITCH.IO', href: 'https://<계정>.itch.io' },
]

const BADGES = ['ENGINE: GODOT 4', 'NEXT: UNITY 3D']

export function Player1() {
  return (
    <section className="sec" id="about">
      <h2 className="sec-head">
        <span className="deco">►</span> PLAYER 1
      </h2>
      <div className="about">
        <p>
          안녕하세요 1인 게임 개발로 개발하는 게임 업로드하는 사이트 운영중입니다. 만들고
          싶은 게임 만드는 중입니다. 나날이 업데이트 중이니 많은 관심 부탁드립니다. ^_^
        </p>
        {LINKS.length > 0 && (
          <div className="links">
            {LINKS.map((l) => (
              <a key={l.label} className="btn" href={l.href}>
                {l.label}
              </a>
            ))}
          </div>
        )}
        <div className="stat">
          {BADGES.map((b) => (
            <span key={b}>{b}</span>
          ))}
        </div>
      </div>
    </section>
  )
}
