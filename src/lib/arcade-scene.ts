import * as THREE from 'three'
import { stationColor, TRAVEL_MS, type ArcadeProject } from './arcade'
import { drawCoverImage, drawScene, type Palette } from './scenes'

export interface ArcadeScene {
  select(index: number): void
  setPalette(palette: Palette): void
  setReducedMotion(reduced: boolean): void
  setVisible(visible: boolean): void
  dispose(): void
}

interface Options {
  index: number
  palette: Palette
  reducedMotion: boolean
  onContextLost(): void
}

/** Loaded only when the arcade approaches the viewport. No permanent render loop. */
export function createArcadeScene(host: HTMLElement, projects: ArcadeProject[], options: Options): ArcadeScene {
  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'low-power' })
  const resources = new Set<{ dispose(): void }>()
  const own = <T extends { dispose(): void }>(resource: T): T => {
    resources.add(resource)
    return resource
  }
  const scene = new THREE.Scene()
  const camera = new THREE.PerspectiveCamera(40, 1, .1, 100)
  const spacing = 4.65
  let palette = options.palette
  let reduced = options.reducedMotion
  let selected = options.index
  let rail = selected
  let from = rail
  let started = 0
  let moving = false
  let visible = true
  let disposed = false
  let frame = 0
  let resizeObserver: ResizeObserver | undefined
  const images: HTMLImageElement[] = []
  const repaint: (() => void)[] = []
  const colored: { material: THREE.MeshBasicMaterial | THREE.SpriteMaterial | THREE.MeshStandardMaterial; color: string }[] = []
  const machines: { screen: THREE.MeshBasicMaterial; neons: THREE.MeshBasicMaterial[]; halo: THREE.SpriteMaterial; pool: THREE.MeshBasicMaterial; light: THREE.PointLight; color: string }[] = []
  const neonColor = (color: string) => palette === 'dmg' ? '#9bbc0f' : color
  const basic = (params: THREE.MeshBasicMaterialParameters) => own(new THREE.MeshBasicMaterial(params))
  const standard = (params: THREE.MeshStandardMaterialParameters) => own(new THREE.MeshStandardMaterial(params))
  const tint = <T extends THREE.MeshBasicMaterial | THREE.SpriteMaterial | THREE.MeshStandardMaterial>(material: T, color: string): T => {
    colored.push({ material, color })
    material.color.set(neonColor(color))
    return material
  }

  function draw() {
    if (disposed || !visible || renderer.getContext().isContextLost()) return
    const mobile = host.clientWidth <= 720
    const x = rail * spacing
    const progress = moving ? Math.min(1, (performance.now() - started) / TRAVEL_MS) : 0
    const sway = moving && !reduced ? Math.sin(Math.PI * progress) * .08 : 0
    camera.position.set(x + (mobile ? 1.55 : 2.2), mobile ? 2.5 : 2.7, mobile ? 8.15 : 7.65)
    camera.lookAt(x + (mobile ? 0 : -1.55), 1.62 + sway, 0)
    renderer.render(scene, camera)
  }

  function animate(now: number) {
    frame = 0
    if (disposed || !visible) return
    const progress = Math.min(1, (now - started) / TRAVEL_MS)
    const eased = progress < .5 ? 4 * progress ** 3 : 1 - (-2 * progress + 2) ** 3 / 2
    rail = from + (selected - from) * eased
    moving = progress < 1
    draw()
    if (moving) frame = requestAnimationFrame(animate)
  }

  function lightSelection() {
    machines.forEach((machine, index) => {
      const active = index === selected
      machine.screen.opacity = active ? 1 : .58
      machine.neons.forEach((material) => { material.opacity = active ? 1 : .42 })
      machine.halo.opacity = active ? .34 : .12
      machine.pool.opacity = active ? .4 : .14
      machine.light.intensity = active ? 12 : 4
    })
  }

  function contextLost(event: Event) {
    event.preventDefault()
    visible = false
    cancelAnimationFrame(frame)
    options.onContextLost()
  }

  function dispose() {
    if (disposed) return
    disposed = true
    cancelAnimationFrame(frame)
    resizeObserver?.disconnect()
    images.forEach((image) => { image.onload = null; image.onerror = null })
    renderer.domElement.removeEventListener('webglcontextlost', contextLost)
    resources.forEach((resource) => resource.dispose())
    renderer.dispose()
    renderer.forceContextLoss()
    renderer.domElement.remove()
  }

  try {
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.7))
    renderer.outputColorSpace = THREE.SRGBColorSpace
    renderer.toneMapping = THREE.ACESFilmicToneMapping
    renderer.toneMappingExposure = 1.1
    renderer.domElement.setAttribute('aria-hidden', 'true')
    renderer.domElement.addEventListener('webglcontextlost', contextLost)
    host.appendChild(renderer.domElement)
    scene.background = new THREE.Color('#080914')
    scene.fog = new THREE.FogExp2('#080914', .037)
    scene.add(new THREE.HemisphereLight(0xadc5ff, 0x171122, 2.1))
    const wash = new THREE.DirectionalLight(0xc4bbff, 2.4)
    wash.position.set(1, 7, 8)
    scene.add(wash)
    const metal = standard({ color: 0x171a30, roughness: .39, metalness: .65 })
    const black = standard({ color: 0x0c0f1b, roughness: .5, metalness: .35 })
    const plastic = standard({ color: 0x262b46, roughness: .7, metalness: .12 })
    const silver = standard({ color: 0x657086, roughness: .34, metalness: .75 })

    function box(w: number, h: number, d: number, material: THREE.Material, x: number, y: number, z: number, parent: THREE.Object3D = scene) {
      const mesh = new THREE.Mesh(own(new THREE.BoxGeometry(w, h, d)), material)
      mesh.position.set(x, y, z)
      parent.add(mesh)
      return mesh
    }

    function tube(a: [number, number, number], b: [number, number, number], color: string, parent: THREE.Object3D, radius = .012) {
      const start = new THREE.Vector3(...a)
      const end = new THREE.Vector3(...b)
      const direction = end.clone().sub(start)
      const material = tint(basic({ transparent: true, toneMapped: false }), color)
      const mesh = new THREE.Mesh(own(new THREE.CylinderGeometry(radius, radius, direction.length(), 7)), material)
      mesh.position.copy(start.add(end).multiplyScalar(.5))
      mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize())
      parent.add(mesh)
      return material
    }

    function texture(w: number, h: number, paint: (ctx: CanvasRenderingContext2D, w: number, h: number) => void) {
      const canvas = document.createElement('canvas')
      canvas.width = w
      canvas.height = h
      const context = canvas.getContext('2d')
      if (!context) throw new Error('Canvas unavailable')
      const map = own(new THREE.CanvasTexture(canvas))
      map.colorSpace = THREE.SRGBColorSpace
      map.anisotropy = Math.min(4, renderer.capabilities.getMaxAnisotropy())
      const update = () => {
        context.clearRect(0, 0, w, h)
        paint(context, w, h)
        map.needsUpdate = true
      }
      repaint.push(update)
      update()
      return map
    }

    const glowMap = texture(128, 128, (ctx, w, h) => {
      const gradient = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2)
      gradient.addColorStop(0, 'rgba(255,255,255,.8)')
      gradient.addColorStop(.25, 'rgba(255,255,255,.38)')
      gradient.addColorStop(1, 'rgba(255,255,255,0)')
      ctx.fillStyle = gradient
      ctx.fillRect(0, 0, w, h)
    })

    const width = Math.max(24, projects.length * spacing + 14)
    const midpoint = (projects.length - 1) * spacing / 2
    box(width, .18, 28, standard({ color: 0x111225, roughness: .26, metalness: .72 }), midpoint, -.12, 3)
    const grid = new THREE.GridHelper(width, Math.ceil(width), 0x4f3f67, 0x242538)
    own(grid.geometry)
    own(grid.material)
    grid.material.transparent = true
    grid.material.opacity = .43
    grid.position.set(midpoint, -.016, 3)
    scene.add(grid)
    box(width, 7, .3, standard({ color: 0x11111f, roughness: .72, metalness: .2 }), midpoint, 3.4, -2.1)
    for (let x = -7; x <= midpoint + width / 2; x += 2.3) box(.055, 7, .09, black, x, 3.4, -1.9)
    tube([-8, 4.42, -1.85], [width, 4.42, -1.85], '#b444ff', scene, .019)
    tube([-8, .11, -1.72], [width, .11, -1.72], '#9652dc', scene)
    tube([-7, .01, 2.35], [width, .01, 2.35], '#391739', scene, .013)
    tube([-7, .012, 2.43], [width, .012, 2.43], '#884561', scene, .007)

    projects.forEach((project, index) => {
      const color = stationColor(index)
      const group = new THREE.Group()
      group.position.x = index * spacing
      scene.add(group)
      const outline = [[-.88, 0], [.62, 0], [.62, 3.55], [-.57, 3.55], [-.73, 3.14], [-.44, 2.91], [-.20, 1.89], [-.94, 1.62], [-.94, 1.36]]
      const shape = new THREE.Shape()
      outline.forEach(([x, y], i) => i ? shape.lineTo(x, y) : shape.moveTo(x, y))
      shape.closePath()
      const sideGeometry = own(new THREE.ExtrudeGeometry(shape, { depth: .10, bevelEnabled: true, bevelSegments: 1, steps: 1, bevelSize: .018, bevelThickness: .018 }))
      sideGeometry.rotateY(Math.PI / 2)
      for (const x of [-.97, .87]) {
        const side = new THREE.Mesh(sideGeometry, metal)
        side.position.x = x
        group.add(side)
      }
      box(1.72, 1.4, 1.24, black, 0, .75, .07, group)
      box(1.72, 1.5, .24, black, 0, 2.27, -.47, group)
      box(1.76, .44, .84, metal, 0, 3.24, .12, group)
      box(1.76, .08, 1.15, black, 0, 3.53, .02, group)
      const titleMap = texture(768, 160, (ctx, w, h) => {
        ctx.fillStyle = '#080713'
        ctx.fillRect(0, 0, w, h)
        ctx.strokeStyle = neonColor(color)
        ctx.lineWidth = 4
        ctx.strokeRect(12, 14, w - 24, h - 28)
        ctx.textAlign = 'center'
        ctx.textBaseline = 'middle'
        ctx.shadowColor = neonColor(color)
        ctx.shadowBlur = 16
        ctx.fillStyle = neonColor(color)
        ctx.font = '37px PS2P, NeoDGM, monospace'
        ctx.fillText(project.title, w / 2, h / 2 + 3, w - 60)
        ctx.shadowBlur = 0
      })
      const marquee = new THREE.Mesh(own(new THREE.PlaneGeometry(1.65, .34)), basic({ map: titleMap, toneMapped: false }))
      marquee.position.set(0, 3.24, .551)
      group.add(marquee)

      const cover = document.createElement('canvas')
      cover.width = 100
      cover.height = 42
      let coverImage: HTMLImageElement | undefined
      const screenMap = texture(512, 416, (ctx, w, h) => {
        drawScene(cover, project.coverScene, palette)
        if (coverImage) drawCoverImage(cover, coverImage, palette)
        ctx.imageSmoothingEnabled = false
        ctx.fillStyle = palette === 'dmg' ? '#0f380f' : '#08061b'
        ctx.fillRect(0, 0, w, h)
        if (project.kind === 'software') {
          ctx.fillStyle = palette === 'dmg' ? '#8bac0f' : '#b7bbce'
          ctx.fillRect(0, 0, 280, h)
          ctx.fillStyle = palette === 'dmg' ? '#306230' : '#7c839d'
          for (let row = 0; row < 7; row++) ctx.fillRect(22, 90 + row * 36, 210 - (row % 3) * 30, 8)
          ctx.drawImage(cover, 291, 100, 213, 150)
          ctx.fillStyle = neonColor(color)
          ctx.fillRect(280, 0, 3, h)
        } else {
          ctx.drawImage(cover, 0, 30, w, 280)
        }
        ctx.fillStyle = 'rgba(0,0,0,.16)'
        for (let row = 0; row < h; row += 4) ctx.fillRect(0, row, w, 1)
      })
      if (project.coverImage) {
        const image = new Image()
        images.push(image)
        const paintScreen = repaint[repaint.length - 1]
        image.onload = () => {
          if (disposed) return
          coverImage = image
          paintScreen()
          draw()
        }
        image.src = project.coverImage
      }
      const bezel = box(1.68, 1.22, .1, plastic, 0, 2.35, .32, group)
      bezel.rotation.x = -.23
      const screenMaterial = basic({ map: screenMap, toneMapped: false, transparent: true })
      const screen = new THREE.Mesh(own(new THREE.PlaneGeometry(1.44, 1.04)), screenMaterial)
      screen.position.set(0, 2.35, .387)
      screen.rotation.x = -.23
      group.add(screen)
      box(1.82, .14, .91, metal, 0, 1.58, .42, group).rotation.x = -.10
      box(1.82, .19, .12, plastic, 0, 1.51, .89, group)
      box(1.52, .8, .035, metal, 0, .93, .71, group)
      box(.43, .50, .025, silver, .24, .88, .74, group)
      box(.34, .41, .018, black, .24, .88, .762, group)
      box(.19, .026, .018, silver, .24, 1, .777, group)
      box(.11, .085, .024, tint(basic({}), color), .24, .81, .781, group)
      box(.47, .09, .014, black, -.40, .69, .75, group)
      const stick = new THREE.Mesh(own(new THREE.CylinderGeometry(.027, .027, .23, 12)), silver)
      stick.position.set(-.43, 1.80, .58)
      group.add(stick)
      const base = new THREE.Mesh(own(new THREE.CylinderGeometry(.105, .12, .035, 16)), silver)
      base.position.set(-.43, 1.69, .58)
      group.add(base)
      const buttonMaterial = tint(standard({ roughness: .25, metalness: .15 }), color)
      const ball = new THREE.Mesh(own(new THREE.SphereGeometry(.105, 14, 12)), buttonMaterial)
      ball.position.set(-.43, 1.94, .58)
      group.add(ball)
      for (let b = 0; b < 3; b++) {
        const button = new THREE.Mesh(own(new THREE.CylinderGeometry(.072, .077, .045, 16)), b === 2 ? silver : buttonMaterial)
        button.position.set(.19 + b * .18, 1.70, .64 - (b % 2) * .12)
        group.add(button)
      }
      const neons: THREE.MeshBasicMaterial[] = []
      for (const x of [-1.015, 1.015]) {
        const points: [number, number, number][] = [[x, .11, .86], [x, 1.36, .95], [x, 1.62, .95], [x, 1.89, .22], [x, 2.91, .46], [x, 3.14, .75], [x, 3.55, .59]]
        for (let p = 1; p < points.length; p++) neons.push(tube(points[p - 1], points[p], color, group, .015))
      }
      neons.push(tube([-1, 3.56, .59], [1, 3.56, .59], color, group, .017))
      neons.push(tube([-.91, .10, .84], [.91, .10, .84], color, group, .014))
      neons.push(tube([-.9, 1.61, .96], [.9, 1.61, .96], color, group, .009))
      const haloMaterial = tint(own(new THREE.SpriteMaterial({ map: glowMap, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })), color)
      const halo = new THREE.Sprite(haloMaterial)
      halo.position.set(0, 2.14, -.95)
      halo.scale.set(5.8, 5.5, 1)
      group.add(halo)
      const poolMaterial = tint(basic({ map: glowMap, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }), color)
      const pool = new THREE.Mesh(own(new THREE.PlaneGeometry(5.1, 6.7)), poolMaterial)
      pool.rotation.x = -Math.PI / 2
      pool.position.set(index * spacing, .003, 1.2)
      scene.add(pool)
      for (const dx of [-.86, .86]) {
        const reflection = new THREE.Mesh(own(new THREE.PlaneGeometry(.11, 2.5)), tint(basic({ transparent: true, opacity: .14, depthWrite: false, blending: THREE.AdditiveBlending }), color))
        reflection.rotation.x = -Math.PI / 2
        reflection.position.set(index * spacing + dx, .008, 2.1)
        scene.add(reflection)
      }
      const light = new THREE.PointLight(neonColor(color), 12, 6, 2)
      light.position.set(index * spacing, 2.5, 1.5)
      scene.add(light)
      const signMap = texture(256, 128, (ctx, w, h) => {
        ctx.fillStyle = '#0e0d1a'
        ctx.fillRect(0, 0, w, h)
        ctx.textAlign = 'center'
        ctx.font = '45px PS2P, monospace'
        ctx.fillStyle = neonColor(color)
        ctx.fillText(String(index + 1).padStart(2, '0'), w / 2, 74)
      })
      const number = new THREE.Mesh(own(new THREE.PlaneGeometry(.72, .36)), basic({ map: signMap, toneMapped: false }))
      number.position.set(-1.51, 3.1, -1.87)
      group.add(number)
      machines.push({ screen: screenMaterial, neons, halo: haloMaterial, pool: poolMaterial, light, color })
    })

    function resize() {
      if (disposed || !host.clientWidth || !host.clientHeight) return
      renderer.setSize(host.clientWidth, host.clientHeight, false)
      camera.aspect = host.clientWidth / host.clientHeight
      camera.updateProjectionMatrix()
      draw()
    }
    resizeObserver = new ResizeObserver(resize)
    resizeObserver.observe(host)
    lightSelection()
    resize()
    void Promise.all([document.fonts.load('16px PS2P'), document.fonts.load('16px NeoDGM')]).then(() => {
      if (disposed) return
      repaint.forEach((paint) => paint())
      draw()
    }).catch(() => { /* System fonts remain usable if a local font cannot load. */ })

    return {
      select(index) {
        selected = Math.max(0, Math.min(projects.length - 1, index))
        lightSelection()
        cancelAnimationFrame(frame)
        if (reduced || !visible) {
          rail = selected
          moving = false
          draw()
        } else {
          from = rail
          started = performance.now()
          moving = true
          frame = requestAnimationFrame(animate)
        }
      },
      setPalette(next) {
        palette = next
        const background = palette === 'dmg' ? '#071b12' : '#080914'
        ;(scene.background as THREE.Color).set(background)
        ;(scene.fog as THREE.FogExp2).color.set(background)
        colored.forEach(({ material, color }) => material.color.set(neonColor(color)))
        machines.forEach(({ light, color }) => light.color.set(neonColor(color)))
        repaint.forEach((paint) => paint())
        draw()
      },
      setReducedMotion(next) {
        reduced = next
        if (reduced) {
          cancelAnimationFrame(frame)
          moving = false
          rail = selected
          draw()
        }
      },
      setVisible(next) {
        visible = next
        cancelAnimationFrame(frame)
        frame = 0
        if (visible) {
          if (moving) frame = requestAnimationFrame(animate)
          else draw()
        }
      },
      dispose,
    }
  } catch (error) {
    dispose()
    throw error
  }
}
