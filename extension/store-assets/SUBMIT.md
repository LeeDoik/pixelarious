# 크롬 웹 스토어 제출 절차

설계 문서: `docs/superpowers/specs/2026-08-22-starfall-drift-extension-design.md`

## 0. 제출 전 체크 (개발자 = Claude/로컬)

```bash
npm test                              # manifest·로케일·패널 정합성 테스트 포함
python scripts/gen_extension_icons.py # 아이콘 재생성 (필요할 때만)
python scripts/gen_store_assets.py    # 프로모 타일 + 스크린샷 합성
python scripts/pack_extension.py      # extension/dist/starfall-drift-v1.0.0.zip
```

**로컬 수동 확인** — 여기서 한 번은 반드시 본다.

1. `chrome://extensions` → 우상단 **개발자 모드** 켜기
2. **압축해제된 확장 프로그램 로드** → `extension/starfall-drift/` 폴더 선택
3. 툴바에서 확장 아이콘 클릭 → 사이드 패널이 열리고 게임이 부팅되는지
4. 한 판 플레이 → 점수 기록 → 패널 닫았다 다시 열어 최고 점수가 남아 있는지
5. 패널에서 우클릭 → 검사 → 콘솔에 에러가 없는지
6. DevTools **Network → Offline** 으로 전환 후 패널 다시 열기 → NO SIGNAL 화면과
   RETRY 버튼 확인 → 온라인 복귀 후 RETRY → 게임 복구
7. 하단 **PIXELARIOUS ↗** 링크가 새 탭으로 사이트를 여는지

스크린샷 3장은 이 과정(4번)에서 직접 찍는다 — `store-assets/captures/README.md` 참고.

## 1. 개발자 등록 (최초 1회, 사용자가 직접)

- https://chrome.google.com/webstore/devconsole 접속 (게시에 쓸 구글 계정으로)
- 개발자 등록비 **US$5** 결제 (평생 1회)
- 개발자 이름을 **PIXELARIOUS** 로 설정하고 연락 이메일 인증

## 2. 새 항목 업로드

1. **새 항목** → `extension/dist/starfall-drift-v1.0.0.zip` 업로드
2. **스토어 등록정보** 탭
   - 이름 / 요약 / 상세 설명 → `listing.md`의 English 블록 붙여넣기
   - 카테고리 **Games**, 언어 **English**
   - 스크린샷 3장(1280×800), 소형 프로모 타일(440×280) 업로드
   - 언어 추가 → 한국어 선택 후 `listing.md`의 한국어 블록 붙여넣기
3. **개인정보 보호** 탭
   - 단일 목적 서술 → `listing.md`의 Single purpose 블록
   - `sidePanel` 권한 사유 → 같은 문서의 Permission justification 블록
   - 원격 코드 사용 → **Yes** + 같은 문서의 설명 블록
   - 데이터 사용: 수집 항목 **전부 체크 해제**, 하단 3개 선언 **전부 체크**
   - 개인정보처리방침 URL → `https://www.pixelarious.online/extension/privacy.html`
     (이 URL이 이미 배포돼 열리는지 먼저 확인할 것 — 심사에서 실제로 접속해 본다)
4. **배포** 탭 → 공개 범위 **공개**, 배포 국가 전체
5. **심사 제출**

통상 수일 내 결과가 온다. 반려되면 사유 메일에 항목이 찍혀 나오므로 그대로 고쳐 재제출.

## 3. 게시 후

- 게임을 다시 배포해도 **확장 재제출은 필요 없다** — 패널이 라이브 사이트를 불러오므로
  사이트 배포 즉시 반영된다.
- 확장 파일 자체를 고쳤을 때만 `manifest.json`의 `version`을 올리고
  `python scripts/pack_extension.py` → 대시보드에서 **새 버전 업로드**.

## 4. 절대 깨면 안 되는 전제

사이트가 `X-Frame-Options` / `Content-Security-Policy: frame-ancestors` 헤더를 보내기
시작하면 확장의 iframe이 통째로 차단돼 게임이 뜨지 않는다. `next.config.ts`에 같은 취지의
주석을 달아 두었다. 헤더를 추가해야 할 일이 생기면 확장 출처
(`chrome-extension://<확장 ID>`)를 `frame-ancestors`에 허용 목록으로 넣어야 한다.
