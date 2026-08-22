# 크롬 확장 — STARFALL DRIFT 사이드 패널

Next.js 사이트 빌드와 완전히 분리된 순수 정적 파일이다. npm 의존성 없음.
설계: `docs/superpowers/specs/2026-08-22-starfall-drift-extension-design.md`
제출 절차: `store-assets/SUBMIT.md`

```
starfall-drift/     확장 본체 (이 폴더가 곧 zip 내용물)
store-assets/       스토어 리스팅용 이미지·문구 (zip에 포함되지 않음)
dist/               패키징 산출물 (gitignore)
```

## 하는 일

툴바 아이콘을 누르면 사이드 패널이 열리고, 그 안에서
`https://www.pixelarious.online/games/starfall-drift/index.html`를 iframe으로 띄운다.
권한은 `sidePanel` 하나뿐 — 호스트 권한도, 콘텐츠 스크립트도, 스토리지도 없다.
게임을 사이트에 재배포하면 확장 재제출 없이 즉시 반영된다.

## 개발

```bash
npm test                              # manifest·로케일·패널 정합성 검증
python scripts/gen_extension_icons.py # 아이콘 16/32/48/128
python scripts/gen_store_assets.py    # 프로모 타일 + 스토어 스크린샷
python scripts/pack_extension.py      # dist/starfall-drift-v<version>.zip
```

로컬 확인: `chrome://extensions` → 개발자 모드 → 압축해제된 확장 프로그램 로드 →
`extension/starfall-drift/` 선택.

## 주의

- 사이트에 `X-Frame-Options` / CSP `frame-ancestors`를 추가하면 확장이 죽는다
  (`next.config.ts` 주석 참고).
- `starfall-drift/fonts/`의 두 폰트는 `public/fonts/`에서 복사한 것이다.
  사이트 폰트를 교체하면 여기도 같이 갱신한다.
