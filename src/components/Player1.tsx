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
      <div className="desk-layout">
        <div className="desk-identity">
          <h2 id="player-title">PLAYER 1</h2>
        </div>
        <div className="about">
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
