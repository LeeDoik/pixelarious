import { getVisibleGames } from '@/lib/games'
import { getProfile } from '@/lib/profile'
import { PaletteSwap } from '@/components/PaletteSwap'
import { Hero } from '@/components/Hero'
import { Cartridge } from '@/components/Cartridge'
import { EmptySlot } from '@/components/EmptySlot'
import { ContinueSlot } from '@/components/ContinueSlot'
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
          <p className="sec-sub">Hover a cartridge to open it — tap on mobile.</p>
          <div className="carts">
            {games.map((g, i) => (
              <Cartridge key={g.slug} game={g} index={i} />
            ))}
            <EmptySlot index={games.length} />
            <ContinueSlot href={profile.donate} index={games.length + 1} />
          </div>
        </section>
        <Player1 profile={profile} />
      </main>
      <Footer />
    </>
  )
}
