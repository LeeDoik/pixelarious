"""목업 HTML의 <style> 블록을 src/app/globals.css로 추출한다.
base64 인라인 폰트는 public/fonts/ 파일 참조로 교체한다.
목업이 갱신되면 재실행해서 CSS를 동기화할 수 있다."""
import re
import pathlib

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
out.write_text(css.strip() + '\n', encoding='utf-8')
print('globals.css written:', len(css), 'chars')
