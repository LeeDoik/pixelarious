import { getVisibleGames } from '@/lib/games'
import { getProfile } from '@/lib/profile'
import { PaletteSwap } from '@/components/PaletteSwap'
import { Hero } from '@/components/Hero'
import { Shelf } from '@/components/Shelf'
import { Player1 } from '@/components/Player1'
import { Footer } from '@/components/Footer'

export default function Home() {
  const games = getVisibleGames()
  const profile = getProfile()
  return (
    <>
      <PaletteSwap />
      <Hero />
      <main className="wrap">
        <section className="sec" id="games">
          <h2 className="sec-head">
            <span className="deco">►</span> SELECT GAME
          </h2>
          <p className="sec-sub">Pick a cartridge from the shelf.</p>
          <Shelf games={games} />
        </section>
        <Player1 profile={profile} />
      </main>
      <Footer />
    </>
  )
}
