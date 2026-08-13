const LINKS: { label: string; href: string }[] = [
  { label: 'EMAIL', href: 'mailto:lee253628@gmail.com' },
  // 준비되면 주석 해제 (죽은 링크 금지 — 스펙 §4.3):
  // { label: 'GITHUB', href: 'https://github.com/<계정>' },
  // { label: 'ITCH.IO', href: 'https://<계정>.itch.io' },
]

const BADGES = ['ENGINE: GODOT 4', 'NEXT: UNITY 3D', 'LOCATION: SEOUL']

export function Player1() {
  return (
    <section className="sec" id="about">
      <h2 className="sec-head">
        <span className="deco">►</span> PLAYER 1
      </h2>
      <div className="about">
        <p>
          안녕하세요, 1인 게임 개발자 <b>LeeDoik</b>입니다. Godot 엔진으로 2D 게임을 만들어
          이곳에서 바로 플레이할 수 있게 배포합니다. 다음 목표는 Unity로 만드는 첫 3D
          게임입니다. 게임 제작 의뢰와 협업 제안은 언제나 환영합니다.
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
