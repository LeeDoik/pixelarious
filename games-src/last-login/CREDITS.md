# LAST LOGIN — Credits & Licenses

- Font: Galmuri (quiple/galmuri) — SIL Open Font License 1.1
- Font: Neo둥근모 / NeoDunggeunmo v1.601 (neodgm/neodgm, © 2017-2021 Eunbin Jeong "Dalgona.")
  — SIL Open Font License 1.1. 예약 글꼴 이름: "Neo둥근모", "NeoDunggeunmo".
  누리넷(브라우저) 본문 전용. web.json 페이지들이 한글 2칸 / ASCII 1칸 격자로 짜여 있는데
  Galmuri는 ASCII 최대폭이 한글의 0.8배라 표가 어긋난다. 이 폰트는 모든 크기에서 정확히 2:1이다.
- Font: 나눔손글씨 가람연꽃 (네이버 클로바 나눔손글씨) — SIL Open Font License 1.1.
  필사 제출본 사진(scripts/gen_pilsa_photos.py)에만 래스터로 쓰인다 — 폰트 파일은 게임에 실리지 않는다.
- Engine: Godot Engine — MIT License
- 사운드: 전량 자체 신디사이징 (scripts/gen_audio.py) — 표준 라이브러리만 사용, 라이선스 청정
- 엔딩곡·메신저 알림음·종료음·창밖 앰비언트: AI 생성 (Higgsfield — Sonilo Music, Seed Audio 1.0), scripts/gen_audio_higgsfield.py로 가공.
  원본과 탈락 후보는 scripts/audio_src/higgsfield/. 상업 이용 조건은 조사 문서(2026-08-19-last-login-research.md §4.3) 참조.
- 클릭·키보드 효과음: 사용자 제공 녹음을 분할·정규화 (scripts/split_clicks.py, 원본 scripts/audio_src/) — 입력마다 랜덤 변주 재생
- 아이콘: AI 생성 픽셀 아트 (PixelLab) — 초기 절차 생성판은 scripts/gen_icons.py
- 누리넷 웹 그래픽 (assets/img/web/): 그림은 PixelLab 생성 (scripts/gen_pixellab_lastlogin.py),
  한글 글자·배너 틀은 게임 폰트로 조립 (scripts/gen_web_banners.py). AI는 한글을 못 그린다.
  미니홈피 프로필·사진첩은 assets/img/photos의 사진을 잘라 쓴다 — 서사에 나오는 그 사진이라야 한다.
- 이미지(사진): AI 생성(Google Gemini, Nano Banana) 후 열화 가공 (scripts/degrade_photo.py).
  실존 인물 없음. 원본은 `scripts/photo_src/`에 보관, 워터마크 영역은 크롭으로 제거.
  교체 절차: 같은 파일명으로 `scripts/photo_src/`에 덮어쓰고 `python scripts/degrade_photo.py` 재실행.
  파일명은 fs.json의 image 노드 경로와 일치해야 한다:
  `family_photo / bomi_2002 / desk_2002 / retreat_2002 / window_night`.
