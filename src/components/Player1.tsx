import type { Profile } from '@/lib/profile'

export function Player1({ profile }: { profile: Profile }) {
  return (
    <section className="sec" id="about">
      <h2 className="sec-head">
        <span className="deco">►</span> PLAYER 1
      </h2>
      <div className="about">
        <p>{profile.intro}</p>
        {profile.links.length > 0 && (
          <div className="links">
            {profile.links.map((link) => (
              <a key={link.label} className="btn" href={link.href}>
                {link.label}
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
    </section>
  )
}
