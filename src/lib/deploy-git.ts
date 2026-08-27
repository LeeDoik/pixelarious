import { execFileSync } from 'node:child_process'
import { DEPLOY_PATHS, commitMessage, parseStatus, type Change, type DeployResult, type DeployState } from './deploy'

/** 배포 = content/ 커밋 + 푸시. Vercel이 master 푸시를 보고 알아서 빌드한다.
 *  서버 전용 — /api/deploy 에서만 부른다. */

function git(args: string[]): string {
  return execFileSync('git', args, {
    cwd: process.cwd(),
    encoding: 'utf-8',
    // 자격 증명을 물어보며 멈추는 대신 바로 실패하게 한다 — 웹 요청 뒤에서
    // 프롬프트가 뜨면 응답이 영원히 돌아오지 않는다.
    env: { ...process.env, GIT_TERMINAL_PROMPT: '0', GIT_OPTIONAL_LOCKS: '0' },
    stdio: ['ignore', 'pipe', 'pipe'],
  })
}

function gitOrThrow(args: string[], what: string): string {
  try {
    return git(args)
  } catch (error) {
    const err = error as { stderr?: string; stdout?: string; message?: string }
    const detail = (err.stderr || err.stdout || err.message || '').trim().split('\n').slice(-4).join('\n')
    throw new Error(`${what} 실패: ${detail || '알 수 없는 오류'}`)
  }
}

function currentBranch(): string {
  return gitOrThrow(['rev-parse', '--abbrev-ref', 'HEAD'], '브랜치 확인').trim()
}

function aheadCount(): number | null {
  try {
    return Number(git(['rev-list', '--count', '@{u}..HEAD']).trim())
  } catch {
    return null // 업스트림이 없는 브랜치
  }
}

export function pendingChanges(): Change[] {
  // --untracked-files=all: 새 폴더를 'content/games/' 한 줄로 접지 않고
  // 파일을 하나씩 세게 한다. 목록이 그대로 편집기 화면에 뜨기 때문이다.
  const out = gitOrThrow(
    [
      '-c', 'core.quotepath=false',
      'status', '--porcelain', '--untracked-files=all',
      '--', ...DEPLOY_PATHS,
    ],
    '변경 확인',
  )
  return parseStatus(out)
}

export function deployState(): DeployState {
  return { branch: currentBranch(), changes: pendingChanges(), ahead: aheadCount() }
}

/** content/ 를 커밋하고 푸시한다. 커밋할 게 없어도 푸시하지 않은 커밋이 있으면
 *  푸시만 한다. 둘 다 없으면 아무것도 하지 않고 pushed=false 로 돌아온다. */
export function deploy(message?: string): DeployResult {
  const branch = currentBranch()
  const changes = pendingChanges()
  const ahead = aheadCount()

  if (changes.length === 0 && ahead === 0) {
    return { branch, changes, ahead, sha: null, subject: null, pushed: false }
  }

  let sha: string | null = null
  let subject: string | null = null

  if (changes.length > 0) {
    const text = (message ?? '').trim() || commitMessage(changes)
    // add 로 새 파일까지 인덱스에 올린 뒤, pathspec 커밋으로 content/ 밖의
    // 스테이징된 변경은 남겨 둔다.
    gitOrThrow(['add', '-A', '--', ...DEPLOY_PATHS], '스테이징')
    gitOrThrow(['commit', '-m', text, '--', ...DEPLOY_PATHS], '커밋')
    sha = gitOrThrow(['rev-parse', '--short', 'HEAD'], '커밋 확인').trim()
    subject = text
  }

  gitOrThrow(['push', 'origin', 'HEAD'], '푸시')

  return { branch, changes, ahead, sha, subject, pushed: true }
}
