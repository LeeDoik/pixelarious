import type { Profile } from '@/lib/profile'

/** 빈 줄로 갈라 문단을 만든다. 넓은 화면에서는 이 문단들이 카드의 좌우 칸을
 *  나눠 갖는다 — 한 덩어리로 두면 오른쪽 절반이 비어 보였다. */
function paragraphs(intro: string): string[] {
  return intro
    .split(/\n\s*\n/)
    .map((part) => part.trim())
    .filter((part) => part.length > 0)
}

export function Player1({ profile }: { profile: Profile }) {
  return (
    <section className="sec" id="about">
      <h2 className="sec-head">
        <span className="deco">►</span> PLAYER 1
      </h2>
      <div className="about">
        {paragraphs(profile.intro).map((part, i) => (
          <p key={i}>{part}</p>
        ))}
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
