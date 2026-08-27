import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { deploy, deployState } from './deploy-git'

/** 진짜 git 저장소와 로컬 bare 리모트를 만들어 배포 경로를 통째로 돌린다.
 *  origin이 임시 폴더라 GitHub에는 아무것도 나가지 않는다. */

const run = (args: string[], cwd: string) =>
  execFileSync('git', args, { cwd, encoding: 'utf-8', stdio: ['ignore', 'pipe', 'pipe'] })

let root = ''
let repo = ''
let origin = ''
const cwdBefore = process.cwd()

beforeEach(() => {
  root = fs.mkdtempSync(path.join(os.tmpdir(), 'deploy-test-'))
  repo = path.join(root, 'repo')
  origin = path.join(root, 'origin.git')

  run(['init', '--bare', '-b', 'master', origin], root)
  run(['init', '-b', 'master', repo], root)
  run(['config', 'user.email', 'test@example.com'], repo)
  run(['config', 'user.name', 'test'], repo)
  run(['remote', 'add', 'origin', origin], repo)

  // content/games 는 일부러 비워 둔다 — 새 폴더에 파일이 생기는 경우까지 훑기 위해.
  fs.mkdirSync(path.join(repo, 'content', 'games'), { recursive: true })
  fs.writeFileSync(path.join(repo, 'content', 'profile.json'), '{"intro":"before"}\n')
  run(['add', '-A'], repo)
  run(['commit', '-m', 'init'], repo)
  run(['push', '-u', 'origin', 'master'], repo)

  process.chdir(repo)
})

afterEach(() => {
  process.chdir(cwdBefore)
  fs.rmSync(root, { recursive: true, force: true })
})

describe('deploy (실제 git)', () => {
  it('깨끗한 저장소에서는 아무것도 하지 않는다', () => {
    const result = deploy()
    expect(result.pushed).toBe(false)
    expect(result.sha).toBeNull()
    expect(run(['rev-list', '--count', 'HEAD'], repo).trim()).toBe('1')
  })

  it('content 변경을 커밋하고 origin에 푸시한다', () => {
    fs.writeFileSync(path.join(repo, 'content', 'profile.json'), '{"intro":"after"}\n')

    const before = deployState()
    expect(before.changes).toEqual([{ code: ' M', path: 'content/profile.json' }])
    expect(before.ahead).toBe(0)

    const result = deploy()
    expect(result.pushed).toBe(true)
    expect(result.sha).toMatch(/^[0-9a-f]{7,}$/)
    expect(result.subject).toBe('chore(content): 편집기에서 profile.json 갱신')

    // 리모트가 실제로 받았는지 — bare 저장소에서 파일을 꺼내 본다.
    expect(run(['show', 'master:content/profile.json'], origin)).toContain('after')
    expect(deployState().changes).toEqual([])
  })

  it('content 밖의 변경은 딸려 올라가지 않는다', () => {
    fs.mkdirSync(path.join(repo, 'games-src'), { recursive: true })
    fs.writeFileSync(path.join(repo, 'games-src', 'secret.txt'), 'not ready\n')
    fs.writeFileSync(path.join(repo, 'content', 'profile.json'), '{"intro":"after"}\n')

    expect(deployState().changes).toEqual([{ code: ' M', path: 'content/profile.json' }])
    deploy()

    expect(() => run(['show', 'master:games-src/secret.txt'], origin)).toThrow()
    expect(run(['status', '--porcelain', '-uall'], repo)).toContain('games-src/secret.txt')
  })

  it('content 밖에 미리 스테이징해 둔 변경도 남겨 둔다', () => {
    fs.mkdirSync(path.join(repo, 'games-src'), { recursive: true })
    fs.writeFileSync(path.join(repo, 'games-src', 'staged.txt'), 'staged\n')
    run(['add', 'games-src/staged.txt'], repo)
    fs.writeFileSync(path.join(repo, 'content', 'profile.json'), '{"intro":"after"}\n')

    deploy()

    expect(() => run(['show', 'master:games-src/staged.txt'], origin)).toThrow()
    expect(run(['diff', '--cached', '--name-only'], repo).trim()).toBe('games-src/staged.txt')
  })

  it('새로 만든 content 파일도 올라간다', () => {
    fs.writeFileSync(path.join(repo, 'content', 'games', '99-new.json'), '{"slug":"new"}\n')

    expect(deployState().changes).toEqual([{ code: '??', path: 'content/games/99-new.json' }])
    deploy()

    expect(run(['show', 'master:content/games/99-new.json'], origin)).toContain('new')
  })

  it('커밋만 있고 푸시가 밀렸으면 푸시만 한다', () => {
    fs.writeFileSync(path.join(repo, 'content', 'profile.json'), '{"intro":"local"}\n')
    run(['commit', '-am', 'local only'], repo)

    const state = deployState()
    expect(state.changes).toEqual([])
    expect(state.ahead).toBe(1)

    const result = deploy()
    expect(result.pushed).toBe(true)
    expect(result.sha).toBeNull()
    expect(run(['show', 'master:content/profile.json'], origin)).toContain('local')
  })

  it('푸시가 거절되면 이유를 담아 던진다', () => {
    // 리모트를 앞서 나가게 만들어 non-fast-forward 를 유도한다.
    const other = path.join(root, 'other')
    run(['clone', origin, other], root)
    run(['config', 'user.email', 'test@example.com'], other)
    run(['config', 'user.name', 'test'], other)
    fs.writeFileSync(path.join(other, 'content', 'profile.json'), '{"intro":"remote"}\n')
    run(['commit', '-am', 'remote moves'], other)
    run(['push'], other)

    fs.writeFileSync(path.join(repo, 'content', 'profile.json'), '{"intro":"mine"}\n')
    expect(() => deploy()).toThrow(/푸시 실패/)
  })
})
