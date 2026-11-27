"""App icon v2: the mihrab-and-crescent mark with «مواقيتي» on a gold band. Writes every size for
Android, the web app, the desktop app (.ico/.png) and the installer splash.
Usage: python3 tools/make_icon.py"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
src = open(os.path.join(ROOT, "tools", "make_assets.py"), encoding="utf-8").read()
ns = {"__file__": os.path.join(ROOT, "tools", "make_assets.py")}
exec(src[: src.index("big = icon(256)")], ns)
# One flat navy behind everything, so the original mark blends in without seams.
NAVY = (13, 38, 68, 255)
ns["NAVY"] = ns["NAVY2"] = NAVY
mark = ns["icon"]  # the original rounded icon (navy square, arch, crescent, star)
FONT = os.path.join(ROOT, "mobile", "assets", "fonts", "Cairo-Bold.ttf")
NAVY_TOP, NAVY_BOT = (18, 52, 86), (11, 31, 58)


def gradient(S, top, bot):
    g = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(g)
    for y in range(S):
        t = y / S
        d.line([(0, y), (S, y)], fill=tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)))
    return g


def master(S=1024, rounded=True, safe=1.0):
    """[safe] < 1 shrinks the artwork into the centre (maskable / adaptive icons)."""
    img = Image.new("RGBA", (S, S), NAVY)
    inner = int(S * safe)
    off = (S - inner) // 2
    # the mark, a little smaller and higher to make room for the band
    m = mark(inner)
    m = m.crop((int(inner * .12), int(inner * .12), int(inner * .88), int(inner * .9))).resize((int(inner * .74), int(inner * .76)), Image.LANCZOS)
    img.alpha_composite(m, (off + (inner - m.width) // 2, off + int(inner * .02)))
    # gold band with the name
    band_h = int(inner * .25)
    y0 = off + inner - band_h if safe < 1 else S - band_h
    band = gradient(S, (240, 211, 107), (184, 144, 31)).crop((0, 0, S, band_h))
    img.paste(band, (0, y0))
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, int(inner * .15), layout_engine=ImageFont.Layout.RAQM)
    d.text((S / 2, y0 + band_h / 2 - inner * .03), "مواقيتي", font=f, fill=(11, 31, 58), anchor="mm", direction="rtl", language="ar")
    if rounded:
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * .22), fill=255)
        out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        out.paste(img, (0, 0), mask)
        img = out
    return img


def save(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path)


big = master()
square = master(rounded=False)
safe = master(rounded=False, safe=.8)
# Android launcher (legacy square icons, the launcher rounds them)
for d, s in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    save(big, f"{ROOT}/mobile/android/app/src/main/res/mipmap-{d}/ic_launcher.png", s)
save(big, f"{ROOT}/mobile/assets/images/logo.png", 256)
# web app
save(big, f"{ROOT}/mobile/web/icons/Icon-192.png", 192)
save(big, f"{ROOT}/mobile/web/icons/Icon-512.png", 512)
save(safe, f"{ROOT}/mobile/web/icons/Icon-maskable-192.png", 192)
save(safe, f"{ROOT}/mobile/web/icons/Icon-maskable-512.png", 512)
save(big, f"{ROOT}/mobile/web/favicon.png", 32)
# desktop
assets = f"{ROOT}/src/Mawaqeety.App/Assets"
save(big, f"{assets}/logo.png", 256)
big.resize((256, 256), Image.LANCZOS).save(f"{assets}/mawaqeety.ico", sizes=[(16, 16), (20, 20), (24, 24), (32, 32), (40, 40), (48, 48), (64, 64), (128, 128), (256, 256)])
save(big, f"{ROOT}/installer/splash.png", 512)
# store icon (Play Console: 512×512, full square)
save(square, f"{ROOT}/mobile/distribution/play-icon-512.png", 512)
print("icons written")
