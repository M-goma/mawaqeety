"""Generates the app icon (.ico/.png) and the built-in notification chime (.wav). No third-party media."""
import math, os, struct, wave
from PIL import Image, ImageDraw, ImageFilter

root = os.path.join(os.path.dirname(__file__), "..", "src", "Mawaqeety.App", "Assets")
os.makedirs(os.path.join(root, "Sounds"), exist_ok=True)

NAVY = (11, 31, 58, 255); NAVY2 = (18, 52, 86, 255)
EMERALD = (14, 138, 95, 255); GOLD = (212, 175, 55, 255); WHITE = (255, 255, 255, 255)

def icon(size):
    S = size * 4  # supersample
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(S * 0.22)
    # vertical gradient rounded square
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / S
        c = tuple(int(NAVY2[i] * (1 - t) + NAVY[i] * t) for i in range(3)) + (255,)
        gd.line([(0, y), (S, y)], fill=c)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=r, fill=255)
    img.paste(grad, (0, 0), mask)
    # emerald arch (mihrab) outline
    w = int(S * 0.06)
    ax0, ax1, ay0, ay1 = int(S * .22), int(S * .78), int(S * .30), int(S * .86)
    # gold crescent
    cx, cy, cr = S * .5, S * .47, S * .17
    d.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=GOLD)
    off = cr * .42
    d.ellipse([cx - cr + off, cy - cr - off * .35, cx + cr + off, cy + cr - off * .35], fill=(0, 0, 0, 0))
    # redraw background where cut (alpha 0 punched through); fill with gradient color
    cut = Image.new("L", (S, S), 0)
    ImageDraw.Draw(cut).ellipse([cx - cr + off, cy - cr - off * .35, cx + cr + off, cy + cr - off * .35], fill=255)
    inner = Image.new("L", (S, S), 0)
    ImageDraw.Draw(inner).rounded_rectangle([0, 0, S - 1, S - 1], radius=r, fill=255)
    cut = Image.composite(cut, Image.new("L", (S, S), 0), inner)
    img.paste(grad, (0, 0), cut)
    # re-stroke the arch on top of the patch
    d = ImageDraw.Draw(img)
    d.arc([ax0, ay0, ax1, ay0 + (ax1 - ax0)], 180, 360, fill=EMERALD, width=w)
    d.line([(ax0 + w / 2, ay0 + (ax1 - ax0) / 2), (ax0 + w / 2, ay1)], fill=EMERALD, width=w)
    d.line([(ax1 - w / 2, ay0 + (ax1 - ax0) / 2), (ax1 - w / 2, ay1)], fill=EMERALD, width=w)
    d.line([(ax0, ay1 - w / 2), (ax1, ay1 - w / 2)], fill=GOLD, width=int(w * .8))
    # small star
    sx, sy, sr = S * .61, S * .40, S * .045
    pts = []
    for k in range(10):
        ang = -math.pi / 2 + k * math.pi / 5
        rr = sr if k % 2 == 0 else sr * .45
        pts.append((sx + rr * math.cos(ang), sy + rr * math.sin(ang)))
    d.polygon(pts, fill=WHITE)
    return img.resize((size, size), Image.LANCZOS)

big = icon(256)
big.save(os.path.join(root, "logo.png"))
big.save(os.path.join(root, "mawaqeety.ico"), sizes=[(16, 16), (20, 20), (24, 24), (32, 32), (40, 40), (48, 48), (64, 64), (128, 128), (256, 256)])
icon(512).save(os.path.join(root, "..", "..", "..", "installer", "splash.png"))

# Soft three-note bell chime, 44.1 kHz mono, ~3.2 s, gentle exponential decay.
rate = 44100
notes = [(0.00, 659.25), (0.45, 783.99), (0.90, 987.77)]  # E5 G5 B5
dur = 3.2
n = int(rate * dur)
samples = [0.0] * n
for start, f in notes:
    s0 = int(start * rate)
    for i in range(s0, n):
        t = (i - s0) / rate
        env = math.exp(-t * 2.2) * min(1, t * 200)
        v = (math.sin(2 * math.pi * f * t) + 0.35 * math.sin(2 * math.pi * f * 2 * t) * math.exp(-t * 3)
             + 0.15 * math.sin(2 * math.pi * f * 3.01 * t) * math.exp(-t * 5))
        samples[i] += 0.28 * env * v
with wave.open(os.path.join(root, "Sounds", "chime.wav"), "w") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))
print("assets ok")
