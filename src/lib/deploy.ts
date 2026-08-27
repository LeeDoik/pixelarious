/** 배포(content/ 커밋 + 푸시)의 순수 부분 — 타입과 문자열 다루기.
 *  git 을 실제로 부르는 쪽은 deploy-git.ts 다. 편집기 화면이 이 파일을
 *  import 하므로 여기에는 node 모듈이 들어오면 안 된다. */

/** 편집기가 건드리는 경로만 스테이징한다. 작업 트리의 다른 변경(게임 소스,
 *  실험 스크립트, 아직 커밋할 생각 없는 것들)이 배포에 딸려 올라가면 안 된다. */
export const DEPLOY_PATHS = ['content'] as const

export interface Change {
  /** git porcelain 2글자 코드 (예: ' M', 'A ', '??') */
  code: string
  path: string
}

export interface DeployState {
  branch: string
  /** 아직 커밋하지 않은 content/ 변경 */
  changes: Change[]
  /** 커밋했지만 아직 푸시하지 않은 개수. 업스트림이 없으면 null */
  ahead: number | null
}

export interface DeployResult extends DeployState {
  /** 이번에 만든 커밋. 커밋할 게 없어 푸시만 했으면 null */
  sha: string | null
  subject: string | null
  pushed: boolean
}

/** `git status --porcelain` 출력을 줄 단위로 읽는다. 이름이 바뀐 파일은
 *  `R  old -> new` 로 나오므로 새 이름만 남긴다. */
export function parseStatus(porcelain: string): Change[] {
  return porcelain
    .split('\n')
    .filter((line) => line.trim() !== '')
    .map((line) => {
      const code = line.slice(0, 2)
      const rest = line.slice(3)
      const arrow = rest.indexOf(' -> ')
      return { code, path: arrow === -1 ? rest : rest.slice(arrow + 4) }
    })
}

const CODE_LABELS: Record<string, string> = {
  M: '수정',
  A: '추가',
  D: '삭제',
  R: '이름 바뀜',
  '?': '새 파일',
}

/** 변경 한 줄을 사람이 읽을 라벨로. 인덱스/작업트리 두 칸 중 비어 있지 않은 쪽을 쓴다. */
export function describeChange(change: Change): string {
  const letter = change.code.trim()[0] ?? '?'
  return CODE_LABELS[letter] ?? '변경'
}

/** 커밋 메시지. 파일이 여러 개면 앞의 하나만 이름을 밝히고 나머지는 개수로 센다. */
export function commitMessage(changes: Change[]): string {
  const names = changes.map((c) => c.path.split('/').pop() ?? c.path)
  if (names.length === 0) return 'chore(content): 편집기에서 갱신'
  if (names.length === 1) return `chore(content): 편집기에서 ${names[0]} 갱신`
  return `chore(content): 편집기에서 ${names[0]} 외 ${names.length - 1}개 갱신`
}
