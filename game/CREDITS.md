# LAST LOGIN — Credits & Licenses

- Font: Galmuri (quiple/galmuri) — SIL Open Font License 1.1
- Engine: Godot Engine — MIT License
- 사운드: 전량 자체 신디사이징 (scripts/gen_audio.py) — 표준 라이브러리만 사용, 라이선스 청정
- 아이콘: 자체 절차 생성 픽셀 아트 (scripts/gen_icons.py)
- 이미지(사진): 자체 절차 생성 및 AI 생성 후 열화 가공 (scripts/degrade_photo.py). 실존 인물 없음

## 후속 작업 (TODO)

- `game/assets/img/photos/*.png` 5장은 **플레이스홀더**다.
  `scripts/gen_placeholder_photos.py`(PIL 절차 생성) → `scripts/degrade_photo.py`로 만든 대역이며,
  나중에 AI 생성 사진(예: "2002 Korean family snapshot, film grain, no real person likeness")을
  `scripts/photo_src/`에 같은 파일명으로 덮어쓰고 `python scripts/degrade_photo.py`만 다시 돌리면 교체된다.
  파일명은 fs.json의 image 노드 경로와 일치해야 한다:
  `family_photo / bomi_2002 / desk_2002 / retreat_2002 / window_night`.
