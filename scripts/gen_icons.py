"""32x32 픽셀 아이콘 생성. 사용: python scripts/gen_icons.py"""
from PIL import Image, ImageDraw
import os

OUT = os.path.join("game", "assets", "img", "icons")
os.makedirs(OUT, exist_ok=True)

def canvas():
    return Image.new("RGBA", (32, 32), (0, 0, 0, 0))

def save(img, name):
    img.save(os.path.join(OUT, name))

# 폴더
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([2, 10, 29, 27], fill=(216, 180, 96), outline=(96, 72, 24))
d.rectangle([2, 6, 14, 12], fill=(216, 180, 96), outline=(96, 72, 24))
save(img, "folder.png")
# 문서
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([6, 3, 25, 29], fill=(240, 240, 232), outline=(90, 90, 90))
for y in (9, 13, 17, 21):
    d.line([9, y, 22, y], fill=(120, 120, 140))
save(img, "doc.png")
# 메신저(말풍선), 메일(봉투), 브라우저(지구), 휴지통(통), 사진(산) — 같은 방식으로 각각 도형 조합
img = canvas(); d = ImageDraw.Draw(img)
d.ellipse([3, 5, 28, 23], fill=(120, 200, 240), outline=(30, 90, 130))
d.polygon([(10, 22), (12, 28), (16, 22)], fill=(120, 200, 240))
save(img, "messenger.png")
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([3, 8, 28, 24], fill=(240, 240, 232), outline=(90, 90, 90))
d.line([3, 8, 16, 17], fill=(90, 90, 90)); d.line([28, 8, 16, 17], fill=(90, 90, 90))
save(img, "mail.png")
img = canvas(); d = ImageDraw.Draw(img)
d.ellipse([4, 4, 27, 27], fill=(90, 170, 220), outline=(20, 70, 110))
d.line([4, 16, 27, 16], fill=(20, 70, 110)); d.arc([9, 4, 22, 27], 0, 360, fill=(20, 70, 110))
save(img, "browser.png")
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([8, 8, 23, 28], fill=(160, 168, 176), outline=(70, 74, 80))
d.rectangle([6, 5, 25, 8], fill=(160, 168, 176), outline=(70, 74, 80))
save(img, "trash.png")
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([3, 5, 28, 26], fill=(200, 220, 240), outline=(80, 90, 100))
d.polygon([(6, 24), (14, 12), (20, 20), (24, 15), (27, 24)], fill=(80, 140, 90))
save(img, "photo.png")
print("ok")
