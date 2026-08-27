import { describe, expect, it } from 'vitest'
import { commitMessage, describeChange, parseStatus, DEPLOY_PATHS } from './deploy'

describe('deploy', () => {
  it('편집기가 건드리는 경로만 배포 대상이다', () => {
    expect([...DEPLOY_PATHS]).toEqual(['content'])
  })

  it('porcelain 출력을 코드와 경로로 가른다', () => {
    const changes = parseStatus(' M content/profile.json\n?? content/games/new.json\n')
    expect(changes).toEqual([
      { code: ' M', path: 'content/profile.json' },
      { code: '??', path: 'content/games/new.json' },
    ])
  })

  it('이름이 바뀐 파일은 새 이름만 남긴다', () => {
    expect(parseStatus('R  content/a.json -> content/b.json')).toEqual([
      { code: 'R ', path: 'content/b.json' },
    ])
  })

  it('빈 출력은 빈 목록이다', () => {
    expect(parseStatus('')).toEqual([])
    expect(parseStatus('\n')).toEqual([])
  })

  it('변경 종류를 한글 라벨로 읽는다', () => {
    expect(describeChange({ code: ' M', path: 'x' })).toBe('수정')
    expect(describeChange({ code: 'A ', path: 'x' })).toBe('추가')
    expect(describeChange({ code: ' D', path: 'x' })).toBe('삭제')
    expect(describeChange({ code: '??', path: 'x' })).toBe('새 파일')
  })

  it('커밋 메시지는 파일 하나면 이름을, 여럿이면 개수를 밝힌다', () => {
    expect(commitMessage([{ code: ' M', path: 'content/profile.json' }])).toBe(
      'chore(content): 편집기에서 profile.json 갱신',
    )
    expect(
      commitMessage([
        { code: ' M', path: 'content/games/last-login.json' },
        { code: ' M', path: 'content/profile.json' },
        { code: '??', path: 'content/games/new.json' },
      ]),
    ).toBe('chore(content): 편집기에서 last-login.json 외 2개 갱신')
  })

  it('변경이 없어도 메시지는 만들어진다', () => {
    expect(commitMessage([])).toMatch(/^chore\(content\):/)
  })
})
