import type { Profile } from '@/lib/profile'

/** Keep the editor's blank-line paragraph convention in the public profile. */
function paragraphs(intro: string): string[] {
  return intro
    .split(/\n\s*\n/)
    .map((part) => part.trim())
    .filter((part) => part.length > 0)
}

export function Player1({ profile }: { profile: Profile }) {
  return (
    <section className="player-desk" id="about" aria-labelledby="player-title">
      <div className="room-eyebrow desk-meta"><span>02 / THE MAKER</span><span className="room-status">SAY HELLO</span></div>
      <div className="desk-layout">
        <div className="desk-identity">
          <div className="desk-nameplate" aria-hidden="true"><span>PLAYER ID</span><strong>P1</strong><span className="desk-nameplate-light">● PIXELARIOUS</span></div>
          <h2 id="player-title">PLAYER 1<span>게임기 뒤의 사람</span></h2>
          <p className="desk-note">만들고, 고치고, 다시 플레이합니다.</p>
        </div>
        <div className="about">
          <div className="desk-panel-head"><span className="room-led" /> A NOTE FROM PLAYER 1<span aria-hidden="true">↙</span></div>
          <div className="desk-intro">
            {paragraphs(profile.intro).map((part, i) => (
              <p key={i}>{part}</p>
            ))}
          </div>
          {profile.links.length > 0 && (
            <div className="links">
              {profile.links.map((link) => (
                <a key={link.label} className="arcade-button arcade-button-outline" href={link.href}>
                  {link.label} <span aria-hidden="true">↗</span>
                </a>
              ))}
            </div>
          )}
          {profile.badges.length > 0 && (
            <div className="stat">
              {profile.badges.map((badge) => (
                <span key={badge}>{badge}</span>
              ))}
            </div>
          )}
        </div>
      </div>
    </section>
  )
}
