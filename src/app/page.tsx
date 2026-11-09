import { getArcadeProjects } from '@/lib/projects'
import { getProfile } from '@/lib/profile'
import { ArcadeHeader } from '@/components/ArcadeHeader'
import { Hero } from '@/components/Hero'
import { NeonArcade } from '@/components/NeonArcade'
import { Player1 } from '@/components/Player1'
import { CoinSlot } from '@/components/CoinSlot'
import { Footer } from '@/components/Footer'

export default function Home() {
  const projects = getArcadeProjects()
  const profile = getProfile()
  return (
    <div className="arcade-world">
      <ArcadeHeader />
      <Hero />
      <main>
        <NeonArcade projects={projects} />
        <div className="arcade-lounge">
          <Player1 profile={profile} />
          <CoinSlot href={profile.donate} />
        </div>
      </main>
      <Footer />
    </div>
  )
}
