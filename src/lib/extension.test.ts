import { describe, it, expect } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'

/** 확장은 npm 빌드와 분리된 순수 정적 파일이라 별도 러너가 없다.
 *  패키징 전에 깨지면 스토어 심사에서 반려되는 것들만 여기서 막는다. */
const EXT = path.join(process.cwd(), 'extension', 'starfall-drift')

const read = (rel: string) => fs.readFileSync(path.join(EXT, rel), 'utf-8')
const manifest = JSON.parse(read('manifest.json'))

describe('chrome extension manifest', () => {
  it('is manifest v3 with a semver-ish version', () => {
    expect(manifest.manifest_version).toBe(3)
    expect(manifest.version).toMatch(/^\d+(\.\d+){1,3}$/)
  })

  it('requests only the sidePanel permission', () => {
    expect(manifest.permissions).toEqual(['sidePanel'])
    expect(manifest.host_permissions).toBeUndefined()
    expect(manifest.content_scripts).toBeUndefined()
    expect(manifest.optional_permissions).toBeUndefined()
  })

  it('declares the side panel entry point and service worker', () => {
    expect(manifest.side_panel.default_path).toBe('sidepanel.html')
    expect(manifest.background.service_worker).toBe('background.js')
    expect(manifest.minimum_chrome_version).toBe('114')
  })

  it('points every declared file at something that exists', () => {
    const refs = [
      manifest.side_panel.default_path,
      manifest.background.service_worker,
      ...Object.values(manifest.icons as Record<string, string>),
    ]
    for (const rel of refs) expect(fs.existsSync(path.join(EXT, rel)), rel).toBe(true)
  })

  it('ships all four icon sizes', () => {
    expect(Object.keys(manifest.icons).sort()).toEqual(['128', '16', '32', '48'])
  })
})

describe('chrome extension localization', () => {
  const locales = fs.readdirSync(path.join(EXT, '_locales'))
  const messages = Object.fromEntries(
    locales.map((l) => [l, JSON.parse(read(path.join('_locales', l, 'messages.json')))]),
  )

  it('has a messages file for the default locale', () => {
    expect(locales).toContain(manifest.default_locale)
  })

  it('defines every __MSG_*__ placeholder used by the manifest', () => {
    const used = [...JSON.stringify(manifest).matchAll(/__MSG_(\w+)__/g)].map((m) => m[1])
    expect(used.length).toBeGreaterThan(0)
    for (const key of used) {
      for (const [locale, msgs] of Object.entries(messages)) {
        expect(msgs[key]?.message, `${locale}/${key}`).toBeTruthy()
      }
    }
  })

  it('keeps every locale on the same key set', () => {
    const sets = Object.values(messages).map((m) => Object.keys(m).sort().join(','))
    expect(new Set(sets).size).toBe(1)
  })

  it('defines every key the side panel script localizes', () => {
    const js = read('sidepanel.js')
    const used = [
      ...[...js.matchAll(/set\('[^']+', '(\w+)'/g)].map((m) => m[1]),
      ...[...js.matchAll(/\bt\('(\w+)'\)/g)].map((m) => m[1]),
    ]
    expect(used.length).toBeGreaterThan(0)
    for (const key of used) expect(messages[manifest.default_locale][key], key).toBeTruthy()
  })
})

describe('chrome extension side panel', () => {
  const html = read('sidepanel.html')
  const js = read('sidepanel.js')

  it('has no inline script or style (blocked by the extension CSP)', () => {
    expect(html).not.toMatch(/<script(?![^>]*\bsrc=)/i)
    expect(html).not.toMatch(/<style[\s>]/i)
    expect(html).not.toMatch(/\son\w+=/i)
  })

  it('loads the game over https from the live site', () => {
    const url = js.match(/const GAME_URL = '([^']+)'/)?.[1]
    expect(url).toBe('https://www.pixelarious.online/games/starfall-drift/index.html')
  })

  it('references only files that ship in the package', () => {
    const refs = [...html.matchAll(/(?:src|href)="(?!https?:|mailto:)([^"]+)"/g)].map((m) => m[1])
    expect(refs.length).toBeGreaterThan(0)
    for (const rel of refs) expect(fs.existsSync(path.join(EXT, rel)), rel).toBe(true)
  })

  it('bundles the fonts the stylesheet asks for', () => {
    const css = read('sidepanel.css')
    const fonts = [...css.matchAll(/url\('([^']+)'\)/g)].map((m) => m[1])
    expect(fonts.length).toBeGreaterThan(0)
    for (const rel of fonts) expect(fs.existsSync(path.join(EXT, rel)), rel).toBe(true)
  })

  it('opens the site link in a new tab with noopener', () => {
    expect(html).toMatch(/target="_blank"[^>]*rel="noopener"/)
  })
})

describe('privacy policy page', () => {
  const file = path.join(process.cwd(), 'public', 'extension', 'privacy.html')

  it('is published where the store listing points', () => {
    expect(fs.existsSync(file)).toBe(true)
  })

  it('states the no-collection policy in both languages', () => {
    const html = fs.readFileSync(file, 'utf-8')
    expect(html).toMatch(/수집·저장·전송하지 않습니다/)
    expect(html).toMatch(/does not collect, store, or transmit any user data/)
  })
})
