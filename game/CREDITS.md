# LAST LOGIN — Credits & Licenses

- Font: Galmuri (quiple/galmuri) — SIL Open Font License 1.1
- Engine: Godot Engine — MIT License
- 사운드: 전량 자체 신디사이징 (scripts/gen_audio.py) — 표준 라이브러리만 사용, 라이선스 청정
- 클릭·키보드 효과음: 사용자 제공 녹음을 분할·정규화 (scripts/split_clicks.py, 원본 scripts/audio_src/) — 입력마다 랜덤 변주 재생
- 아이콘: 자체 절차 생성 픽셀 아트 (scripts/gen_icons.py)
- 이미지(사진): AI 생성(Google Gemini, Nano Banana) 후 열화 가공 (scripts/degrade_photo.py).
  실존 인물 없음. 원본은 `scripts/photo_src/`에 보관, 워터마크 영역은 크롭으로 제거.
  교체 절차: 같은 파일명으로 `scripts/photo_src/`에 덮어쓰고 `python scripts/degrade_photo.py` 재실행.
  파일명은 fs.json의 image 노드 경로와 일치해야 한다:
  `family_photo / bomi_2002 / desk_2002 / retreat_2002 / window_night`.
