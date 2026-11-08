import { getArcadeProjects } from '@/lib/projects'
import { getProfile } from '@/lib/profile'
import { PaletteSwap } from '@/components/PaletteSwap'
import { Hero } from '@/components/Hero'
import { NeonArcade } from '@/components/NeonArcade'
import { Player1 } from '@/components/Player1'
import { CoinSlot } from '@/components/CoinSlot'
import { Footer } from '@/components/Footer'

export default function Home() {
  const projects = getArcadeProjects()
  const profile = getProfile()
  return (
    <>
      <PaletteSwap />
      <Hero />
      <main>
        <NeonArcade projects={projects} />
        <div className="wrap">
          <CoinSlot href={profile.donate} />
          <Player1 profile={profile} />
        </div>
      </main>
      <Footer />
    </>
  )
}
