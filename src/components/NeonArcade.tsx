'use client'

import Link from 'next/link'
import { useCallback, useEffect, useRef, useState, type CSSProperties, type MouseEvent, type PointerEvent } from 'react'
import { ArcadeWheelGesture, stationColor, swipeDirection, TRAVEL_MS, type ArcadeProject } from '@/lib/arcade'
import type { ArcadeScene } from '@/lib/arcade-scene'
import { usePalette } from './ThemeProvider'
import { CoverCanvas } from './CoverCanvas'
import styles from './NeonArcade.module.css'

export function NeonArcade({ projects }: { projects: ArcadeProject[] }) {
  const { palette } = usePalette()
  const [index, setIndex] = useState(0)
  const [status, setStatus] = useState<'waiting' | 'ready' | 'fallback'>('waiting')
  const [dialog, setDialog] = useState<'details' | 'pc' | null>(null)
  const root = useRef<HTMLElement>(null)
  const host = useRef<HTMLDivElement>(null)
  const scene = useRef<ArcadeScene | null>(null)
  const modal = useRef<HTMLDialogElement>(null)
  const gesture = useRef(new ArcadeWheelGesture())
  const drag = useRef<{ id: number; x: number; y: number } | null>(null)
  const current = useRef({ index: 0, palette, reduced: false, busyUntil: 0, alignUntil: 0, dialog: false })
  const project = projects[index]
  const count = projects.length

  useEffect(() => {
    current.current.palette = palette
    scene.current?.setPalette(palette)
  }, [palette])

  useEffect(() => {
    const media = window.matchMedia('(prefers-reduced-motion: reduce)')
    const update = () => {
      current.current.reduced = media.matches
      scene.current?.setReducedMotion(media.matches)
    }
    update()
    media.addEventListener('change', update)
    return () => media.removeEventListener('change', update)
  }, [])

  useEffect(() => {
    if (!host.current || !root.current || !count) return
    let cancelled = false
    let loading = false
    let isVisible = false
    const mount = host.current
    const load = async () => {
      if (loading) return
      loading = true
      try {
        const { createArcadeScene } = await import('@/lib/arcade-scene')
        if (cancelled) return
        const state = current.current
        scene.current = createArcadeScene(mount, projects, {
          index: state.index,
          palette: state.palette,
          reducedMotion: state.reduced,
          onContextLost: () => { if (!cancelled) setStatus('fallback') },
        })
        scene.current.setPalette(state.palette)
        scene.current.setVisible(isVisible)
        setStatus('ready')
      } catch {
        if (!cancelled) setStatus('fallback')
      }
    }
    if (typeof IntersectionObserver === 'undefined') {
      isVisible = true
      void load()
      return () => { cancelled = true; scene.current?.dispose(); scene.current = null }
    }
    const preload = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) { void load(); preload.disconnect() }
    }, { rootMargin: '0px 0px -1px 0px' })
    const visibility = new IntersectionObserver(([entry]) => {
      isVisible = entry.isIntersecting
      scene.current?.setVisible(isVisible && !document.hidden)
    })
    const documentVisibility = () => scene.current?.setVisible(isVisible && !document.hidden)
    preload.observe(root.current)
    visibility.observe(root.current)
    document.addEventListener('visibilitychange', documentVisibility)
    return () => {
      cancelled = true
      preload.disconnect()
      visibility.disconnect()
      document.removeEventListener('visibilitychange', documentVisibility)
      scene.current?.dispose()
      scene.current = null
    }
  }, [projects, count])

  const go = useCallback((next: number) => {
    const state = current.current
    const behavior = state.reduced ? 'instant' : 'smooth'
    if (next < 0) {
      window.scrollTo({ top: 0, behavior })
      return
    }
    if (next >= count) {
      document.getElementById('about')?.scrollIntoView({ behavior, block: 'start' })
      return
    }
    if (next === state.index) return
    state.index = next
    state.busyUntil = performance.now() + (state.reduced ? 0 : TRAVEL_MS)
    setIndex(next)
    scene.current?.select(next)
  }, [count])

  useEffect(() => {
    const element = root.current
    if (!element) return
    const wheel = (event: WheelEvent) => {
      const state = current.current
      if (event.ctrlKey || event.metaKey || state.dialog || !event.cancelable) return
      const rawDelta = Math.abs(event.deltaX) > Math.abs(event.deltaY) ? event.deltaX : event.deltaY
      const delta = rawDelta * (event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? window.innerHeight : 1)
      if (!delta) return
      const rect = element.getBoundingClientRect()
      // Short viewports keep native scrolling so every control remains reachable.
      if (rect.height > window.innerHeight + 4) return
      const now = performance.now()
      if (now < state.alignUntil && Math.abs(rect.top) > 4) {
        event.preventDefault()
        gesture.current.lock(now)
        return
      }
      // Observe the page so a large wheel event starting over the hero cannot skip the room.
      const approaching = (rect.top > 4 && delta > 0 && (rect.top < window.innerHeight * .6 || delta >= rect.top))
        || (rect.top < -4 && delta < 0 && (rect.bottom > window.innerHeight * .6 || -delta >= -rect.top))
      if (approaching) {
        event.preventDefault()
        gesture.current.lock(now)
        state.alignUntil = now + (state.reduced ? 0 : 600)
        element.scrollIntoView({ behavior: state.reduced ? 'instant' : 'smooth', block: 'start' })
        return
      }
      if (Math.abs(rect.top) > 4) return
      const result = gesture.current.read(delta, now, state.index, count, now < state.busyUntil)
      if (result === 'release') return
      event.preventDefault()
      if (result === 'next') go(state.index + 1)
      if (result === 'previous') go(state.index - 1)
    }
    window.addEventListener('wheel', wheel, { passive: false })
    return () => window.removeEventListener('wheel', wheel)
  }, [count, go])

  useEffect(() => {
    current.current.dialog = dialog !== null
    if (!dialog || !modal.current) return
    const element = modal.current
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    element.showModal()
    return () => {
      element.close()
      document.body.style.overflow = previousOverflow
      current.current.dialog = false
    }
  }, [dialog])

  function pointerDown(event: PointerEvent<HTMLDivElement>) {
    if (!event.isPrimary || event.button !== 0 || performance.now() < current.current.busyUntil) return
    drag.current = { id: event.pointerId, x: event.clientX, y: event.clientY }
    event.currentTarget.setPointerCapture(event.pointerId)
  }

  function pointerUp(event: PointerEvent<HTMLDivElement>) {
    const start = drag.current
    drag.current = null
    if (!start || start.id !== event.pointerId) return
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId)
    const direction = swipeDirection(event.clientX - start.x, event.clientY - start.y)
    if (direction) go(current.current.index + direction)
  }

  function play(event: MouseEvent<HTMLAnchorElement>) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    if (project.pcRecommended && window.matchMedia('(pointer: coarse)').matches) {
      event.preventDefault()
      setDialog('pc')
    }
  }

  if (!project) return null
  const external = project.kind === 'software'
  const action = external ? '↗ OPEN PROJECT' : '▶ START GAME'
  const accent = palette === 'dmg' ? '#9bbc0f' : stationColor(index)

  return (
    <section
      ref={root} id="games" className={styles.arcade} data-palette={palette} data-renderer={status}
      style={{ '--arc-accent': accent } as CSSProperties}
      aria-label="네온 오락실 작품 전시" tabIndex={0}
      onKeyDown={(event) => {
        if ((event.target as HTMLElement).closest('button, a, dialog') || event.altKey || event.ctrlKey || event.metaKey || event.repeat) return
        const direction = ['ArrowDown', 'ArrowRight'].includes(event.key) ? 1 : ['ArrowUp', 'ArrowLeft'].includes(event.key) ? -1 : 0
        if (direction) { event.preventDefault(); go(current.current.index + direction) }
      }}
    >
      <header className={styles.header}>
        <div><span className={styles.openDot} /> THE ARCADE <span className={styles.headerCaption}>작은 소프트웨어 전시실</span></div>
        <button className={styles.entrance} onClick={() => go(-1)}>↑ 입구</button>
      </header>

      <div
        className={styles.stage} onPointerDown={pointerDown} onPointerUp={pointerUp}
        onPointerCancel={() => { drag.current = null }} onLostPointerCapture={() => { drag.current = null }}
        aria-hidden="true"
      >
        <div ref={host} className={styles.render} />
        {status !== 'ready' && (
          <div className={styles.fallback}>
            <div className={styles.cabinet}>
              <div className={styles.marquee}>{project.title}</div>
              <div className={styles.screen}><CoverCanvas scene={project.coverScene} image={project.coverImage} /></div>
              <div className={styles.deck}>● <span>● ● ●</span></div>
              <div className={styles.coin}>INSERT CURIOSITY</div>
            </div>
          </div>
        )}
      </div>
      <div className={styles.shade} aria-hidden="true" />
      <span className={styles.floorLabel} aria-hidden="true">NO COINS NEEDED. JUST CURIOSITY.</span>
      <div className={styles.copy} key={project.slug}>
        <p className={styles.eyebrow}>{String(index + 1).padStart(2, '0')} / {project.category ?? (external ? 'SOFTWARE' : 'PLAYABLE GAME')}</p>
        <h2 className={styles.title}>{project.title}</h2>
        {project.subtitle && <p className={styles.subtitle}>{project.subtitle}</p>}
        <p className={styles.description}>{project.description.split('\n')[0]}</p>
        <p className={styles.platform}>{external ? '설치 방법과 소스 보기' : project.pcRecommended ? '마우스를 사용하는 PC 플레이 권장' : '설치 없이 브라우저에서 바로 플레이'}</p>
        <div className={styles.actions}>
          {project.href ? external ? (
            <a className={styles.start} href={project.href} target="_blank" rel="noopener noreferrer">{action}</a>
          ) : (
            <Link className={styles.start} href={project.href} prefetch={false} onClick={play}>{action}</Link>
          ) : <span className={styles.unavailable}>COMING SOON</span>}
          <button className={styles.more} onClick={() => setDialog('details')}>작품 소개 <span aria-hidden="true">↗</span></button>
        </div>
      </div>

      <nav className={styles.navigation} aria-label="작품 이동">
        <button className={styles.step} onClick={() => go(index - 1)}><span aria-hidden="true">←</span> {index === 0 ? '입구로' : '이전 자리'}</button>
        <div className={styles.stationPicker}>
          <div className={styles.stations}>
            {projects.map((item, station) => (
              <button key={item.slug} className={styles.station} aria-label={`${station + 1}. ${item.title}`} aria-current={station === index ? 'step' : undefined} onClick={() => go(station)}>
                <span />
              </button>
            ))}
          </div>
          <span className={styles.count}>{String(index + 1).padStart(2, '0')} / {String(count).padStart(2, '0')}</span>
        </div>
        <button className={styles.step} onClick={() => go(index + 1)}>{index === count - 1 ? 'PLAYER 1' : '다음 자리'} <span aria-hidden="true">→</span></button>
      </nav>
      <p className={styles.gesture}>드래그 · 스크롤 · 방향키로 한 자리씩</p>
      <p className={styles.srOnly} role="status" aria-live="polite">{index + 1} / {count} — {project.title}</p>

      {dialog && (
        <dialog ref={modal} className={styles.dialog} aria-labelledby="arcade-dialog-title" onCancel={() => setDialog(null)} onClick={(event) => { if (event.target === event.currentTarget) setDialog(null) }}>
          <div className={styles.dialogBody}>
            <p className={styles.eyebrow}>{dialog === 'pc' ? 'PC RECOMMENDED' : 'ABOUT THIS PROJECT'}</p>
            <h2 id="arcade-dialog-title">{project.title}</h2>
            <p className={styles.detailCopy}>{dialog === 'pc' ? '이 게임은 마우스 조작에 맞춰 만들었습니다. PC에서 플레이하면 더 편하게 즐길 수 있어요.' : project.description}</p>
            {dialog === 'details' && <ul className={styles.tags}>{project.tags.map((tag) => <li key={tag}>{tag}</li>)}</ul>}
            <div className={styles.dialogActions}>
              {dialog === 'pc' && project.href && <Link href={project.href} className={styles.start} prefetch={false}>그래도 플레이</Link>}
              <button className={styles.more} onClick={() => setDialog(null)} autoFocus>{dialog === 'pc' ? '돌아가기' : '닫기 ×'}</button>
            </div>
          </div>
        </dialog>
      )}
      <noscript><div className={styles.noScript}>{projects.map((item) => item.href && <a key={item.slug} href={item.href}>{item.title} ↗</a>)}</div></noscript>
    </section>
  )
}
