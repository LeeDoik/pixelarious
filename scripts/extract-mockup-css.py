"""목업 HTML의 <style> 블록을 src/app/globals.css로 추출한다.
base64 인라인 폰트는 public/fonts/ 파일 참조로 교체한다.
목업이 갱신되면 재실행해서 CSS를 동기화할 수 있다.

src/app/globals.css에는 스크립트 실행 후 손으로 추가한 CSS(예: play page shell,
not-inserted 상태 스타일)가 있을 수 있다. 이런 손 추가분을 재실행 시 덮어쓰지
않도록, 파일 안에서 MARKER 줄을 찾아 그 줄부터 파일 끝까지를 그대로 보존한 뒤
새로 추출한 CSS 뒤에 이어붙인다. 기존 파일이 없거나 마커가 없으면 이전과 동일하게
추출한 CSS만 기록한다.
"""
import re
import pathlib

MARKER = (
    '/* --- app additions below this line (not from mockup) '
    '— preserved by extract script --- */'
)

src = pathlib.Path('docs/superpowers/specs/2026-08-13-neo-kido-mockup.html').read_text(encoding='utf-8')
css = re.search(r'<style>\n?(.*?)</style>', src, re.S).group(1)
css = re.sub(
    r"@font-face\{font-family:'PS2P';[^}]*\}",
    "@font-face{font-family:'PS2P';src:url('/fonts/press-start-2p.woff2') format('woff2');font-display:block}",
    css,
)
css = re.sub(
    r"@font-face\{font-family:'NeoDGM';[^}]*\}",
    "@font-face{font-family:'NeoDGM';src:url('/fonts/neodgm.woff2') format('woff2');font-display:block}",
    css,
)

out = pathlib.Path('src/app/globals.css')
out.parent.mkdir(parents=True, exist_ok=True)

content = css.strip() + '\n'
if out.exists():
    existing = out.read_text(encoding='utf-8')
    marker_index = existing.find(MARKER)
    if marker_index != -1:
        preserved = existing[marker_index:]
        content = content + '\n' + preserved

out.write_text(content, encoding='utf-8')
print('globals.css written:', len(content), 'chars')
