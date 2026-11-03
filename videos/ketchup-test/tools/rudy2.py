#!/usr/bin/env python3
"""Rudy, redrawn in the 'TV cartoon' house style: white mask faces with no nose,
bean eyes, even dark-grey line, ribbed cuffs, fold lines, sausage-finger gloves.

python3 tools/rudy2.py  -> stills/rudy2.html (render with tools/still.cjs)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ink  # noqa: E402
from ink import blob, brush, defs_common, rrect, set_light  # noqa: E402

LINE = "#3b3536"
ink.INK = LINE
from ink import lit as _lit  # noqa: E402


def lit(d, base, shade, depth=14, line=7, air=0.16, **kw):
    """House style: even line weight (no swell), soft shade."""
    return _lit(d, base, shade, depth=depth, line=line, air=air, swell=1.0, **kw)


def ln(pts, w=6, color=LINE, taper=(0.18, 0.18), opacity=1.0):
    return brush(pts, w=w, taper=taper, color=color, opacity=opacity)


WHITE, WHITE_SH = "#ffffff", "#e3e1e6"
HOOD, HOOD_SH, HOOD_DK = "#4f8d88", "#3b6f6c", "#2c5653"
BEANIE, BEANIE_SH, BEANIE_DK = "#d9a046", "#b88234", "#8e6326"
HAIR, HAIR_SH = "#5a3a2c", "#3f271e"
MOUTH_IN = "#d98a8e"
RED, RED_SH = "#d93a2f", "#a92a22"


def head(cx, cy, s=1.0, mood="grin"):
    """Three-quarter view facing screen right. (cx, cy) = centre of the face."""
    def P(x, y):
        return (cx + x * s, cy + y * s)
    set_light(-1, -0.7)
    face = blob([P(-200, 30), P(-192, -90), P(-112, -162), P(0, -182), P(112, -170), P(186, -112), P(206, -24),
                 P(236, 36), P(234, 112), P(196, 166), P(96, 196), P(-36, 196), P(-150, 156)], 0.5)
    ear = blob([P(-170, 0), P(-222, -10), P(-240, 40), P(-222, 92), P(-168, 92)], 0.6)
    hair_l = blob([P(-182, -40), P(-150, -64), P(-132, -30), P(-150, 6), P(-176, 30)], 0.5)
    hair_f = blob([P(-60, -120), P(-20, -150), P(40, -150), P(110, -132), P(150, -100), P(118, -92), P(84, -112),
                   P(70, -80), P(30, -104), P(4, -70), P(-20, -104), P(-46, -80)], 0.45)
    cuff = blob([P(-206, -64), P(-170, -140), P(-40, -184), P(100, -182), P(200, -132), P(218, -76), P(176, -88),
                 P(60, -112), P(-60, -106), P(-180, -34)], 0.45)
    dome = blob([P(-176, -112), P(-150, -226), P(-60, -292), P(60, -302), P(160, -256), P(206, -156), P(192, -104),
                 P(60, -142), P(-80, -138)], 0.5)
    pom = blob([P(-10, -308), P(16, -346), P(62, -352), P(94, -326), P(96, -286), P(60, -264), P(14, -270)], 0.6)
    ribs = "".join(ln([P(x, -158 + abs(x) * 0.12), P(x + 6, -102 + abs(x) * 0.08)], w=5, color=BEANIE_DK)
                   for x in range(-150, 200, 34))
    # eyes: small black beans, the far eye a little narrower
    if mood == "squint":
        eyes = (ln([P(-60, 8), P(-40, -10), P(-18, 6)], w=9) + ln([P(70, 2), P(90, -16), P(112, 0)], w=8))
    elif mood == "wide":
        eyes = (f'<ellipse cx="{P(-38, 2)[0]}" cy="{P(-38, 2)[1]}" rx="{17 * s}" ry="{25 * s}" fill="{LINE}"/>'
                f'<ellipse cx="{P(92, -2)[0]}" cy="{P(92, -2)[1]}" rx="{15 * s}" ry="{23 * s}" fill="{LINE}"/>')
    else:
        eyes = (f'<ellipse cx="{P(-14, 6)[0]}" cy="{P(-14, 6)[1]}" rx="{16 * s}" ry="{24 * s}" fill="{LINE}" transform="rotate(6 {P(-14, 6)[0]} {P(-14, 6)[1]})"/>'
                f'<ellipse cx="{P(116, 0)[0]}" cy="{P(116, 0)[1]}" rx="{14 * s}" ry="{22 * s}" fill="{LINE}" transform="rotate(6 {P(116, 0)[0]} {P(116, 0)[1]})"/>')
    brows = (brush([P(-58, -44), P(-24, -62), P(16, -54)], w=17 * s, taper=(0.3, 0.2), color=LINE) +
             brush([P(84, -58), P(118, -66), P(152, -50)], w=16 * s, taper=(0.2, 0.3), color=LINE))
    if mood in ("grin", "squint"):
        mouth_d = blob([P(40, 104), P(110, 112), P(206, 82), P(196, 134), P(150, 162), P(84, 160), P(50, 134)], 0.4)
        mouth = (f'<path d="{mouth_d}" fill="{MOUTH_IN}" stroke="{LINE}" stroke-width="{7 * s}" stroke-linejoin="round"/>'
                 + f'<path d="M{P(48, 110)[0]} {P(48, 110)[1]} Q{P(118, 122)[0]} {P(118, 122)[1]} {P(200, 90)[0]} {P(200, 90)[1]} L{P(196, 106)[0]} {P(196, 106)[1]} Q{P(118, 138)[0]} {P(118, 138)[1]} {P(52, 124)[0]} {P(52, 124)[1]} Z" fill="#ffffff"/>'
                 + f'<path d="{blob([P(86, 150), P(130, 134), P(176, 140), P(152, 160), P(100, 162)], 0.5)}" fill="#c06b72"/>')
    else:
        mouth = ln([P(30, 108), P(90, 124), P(150, 100)], w=8)
    return f"""
      <g class="rudy-head">
        {lit(ear, WHITE, WHITE_SH, depth=8, line=7)}
        {ln([P(-214, 20), P(-226, 46), P(-210, 70)], w=5)}
        {lit(face, WHITE, WHITE_SH, depth=18, line=9, air=0.12)}
        {lit(hair_l, HAIR, HAIR_SH, depth=6, line=6)}
        {ln([P(-168, -20), P(-150, 10)], w=4, color="#7a5644")}
        {lit(hair_f, HAIR, HAIR_SH, depth=6, line=6)}
        {ln([P(0, -130), P(16, -96)], w=4, color="#7a5644")}{ln([P(64, -126), P(78, -96)], w=4, color="#7a5644")}
        {lit(dome, BEANIE, BEANIE_SH, depth=26, line=9)}
        {ln([P(-110, -260), P(-60, -300)], w=5, color=BEANIE_DK)}{ln([P(100, -300), P(150, -250)], w=5, color=BEANIE_DK)}
        {lit(cuff, BEANIE_SH, BEANIE_DK, depth=12, line=9)}
        {ribs}
        {lit(pom, "#f4ead6", "#d6c6a6", depth=12, line=7)}
        {ln([P(14, -360), P(30, -376)], w=4, color="#cbb894")}{ln([P(50, -340), P(70, -356)], w=4, color="#cbb894")}
        {brows}
        {eyes}
        {mouth}
      </g>"""


def sleeve(p0, p1, w0, w1, folds=2, cuff=True):
    LW = 8.5
    """Hoodie sleeve segment with fold lines and a ribbed cuff at p1."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux
    out = ink.limb(p0, p1, w0, w1, HOOD, HOOD_SH, line=LW)
    for i in range(folds):
        t = 0.35 + 0.25 * i
        cx, cy = x0 + dx * t, y0 + dy * t
        w = (w0 + (w1 - w0) * t) / 2
        out += ln([(cx + nx * w * 0.9, cy + ny * w * 0.9), (cx + ux * 14 + nx * w * 0.2, cy + uy * 14 + ny * w * 0.2),
                   (cx + ux * 6 - nx * w * 0.3, cy + uy * 6 - ny * w * 0.3)], w=5, color=HOOD_DK)
    if cuff:
        cw = w1 * 1.04
        c0 = (x1 - ux * 34, y1 - uy * 34)
        d = (f"M{c0[0] + nx * cw / 2:.1f} {c0[1] + ny * cw / 2:.1f} L{x1 + nx * cw / 2:.1f} {y1 + ny * cw / 2:.1f} "
             f"L{x1 - nx * cw / 2:.1f} {y1 - ny * cw / 2:.1f} L{c0[0] - nx * cw / 2:.1f} {c0[1] - ny * cw / 2:.1f} Z")
        out += lit(d, HOOD_SH, HOOD_DK, depth=6, line=6.5)
        for k in range(1, 5):
            f = k / 5
            a = (c0[0] + nx * cw / 2 * (1 - 2 * f), c0[1] + ny * cw / 2 * (1 - 2 * f))
            out += ln([a, (a[0] + ux * 30, a[1] + uy * 30)], w=3.5, color=HOOD_DK)
    return out


def glove_hold(cx, cy, s=1.0, angle=0.0, flip=False):
    """Glove wrapped round a vertical handle at (cx, cy): back of the hand, four finger rolls, thumb over the top."""
    sx = -1 if flip else 1

    def P(x, y):
        a = math.radians(angle)
        x, y = x * s * sx, y * s
        return (cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a))
    palm = blob([P(-70, -58), P(-10, -70), P(30, -50), P(36, 40), P(10, 66), P(-60, 60), P(-84, 0)], 0.5)
    out = lit(palm, WHITE, WHITE_SH, depth=10, line=7)
    for i, y in enumerate((-46, -14, 18, 48)):
        h = 30 if i < 3 else 26
        f = blob([P(0, y - h / 2), P(58, y - h / 2 - 2), P(74, y), P(58, y + h / 2), P(0, y + h / 2)], 0.55)
        out += lit(f, WHITE, WHITE_SH, depth=6, line=6)
    thumb = blob([P(-60, -64), P(-20, -92), P(22, -90), P(40, -72), P(10, -56), P(-30, -44)], 0.5)
    out += lit(thumb, WHITE, WHITE_SH, depth=6, line=6)
    out += ln([P(-64, -20), P(-50, 10)], w=4, color="#b9b5c2")
    return out


def bottle(cx, cy, s=1.0, angle=0.0):
    """Squeeze bottle centred at (cx, cy), nozzle up before rotation."""
    def P(x, y):
        a = math.radians(angle)
        x, y = x * s, y * s
        return (cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a))
    body = blob([P(-58, -90), P(0, -104), P(58, -90), P(64, 40), P(58, 110), P(0, 122), P(-58, 110), P(-64, 40)], 0.5)
    cap = blob([P(-38, -100), P(38, -100), P(40, -142), P(-40, -142)], 0.15)
    noz = blob([P(-16, -140), P(16, -140), P(7, -180), P(-7, -180)], 0.1)
    label = blob([P(-48, -30), P(48, -30), P(50, 50), P(-50, 50)], 0.3)
    return (lit(noz, "#f7f3ec", "#d2ccc8", depth=4, line=6) + lit(cap, "#f7f3ec", "#d2ccc8", depth=6, line=6.5)
            + lit(body, RED, RED_SH, depth=18, line=7)
            + lit(label, "#f6e9c8", "#e0cc9e", depth=6, line=5.5)
            + f'<circle cx="{P(0, 10)[0]:.1f}" cy="{P(0, 10)[1]:.1f}" r="{22 * s:.1f}" fill="{RED}" stroke="{LINE}" stroke-width="4.5"/>'
            + brush([P(-14, -14), P(-2, -24), P(12, -14)], w=7, taper=(0.3, 0.3), color="#5f9a4c")
            + brush([P(-40, -80), P(-44, -40)], w=10, taper=(0.4, 0.4), color="#f0796c", opacity=0.9))


PURPLE, PURPLE_SH, PURPLE_DK = "#8a6aa6", "#6c518a", "#553f6f"
GINGER, GINGER_SH = "#c9733a", "#9e5528"


def friend_head(cx, cy, s=1.0):
    """The friend: faces screen left, scrunched in disgust, tongue out."""
    def P(x, y):
        return (cx - x * s, cy + y * s)
    face = blob([P(-196, 30), P(-186, -90), P(-108, -160), P(0, -178), P(110, -166), P(182, -108), P(202, -20),
                 P(226, 40), P(222, 110), P(186, 160), P(90, 190), P(-36, 190), P(-148, 150)], 0.5)
    ear = blob([P(-178, 0), P(-226, -6), P(-244, 40), P(-226, 90), P(-176, 90)], 0.6)
    curls = []
    for (x, y, r) in ((-170, -110, 70), (-90, -170, 78), (10, -196, 80), (110, -170, 74), (180, -110, 60), (-200, -20, 56)):
        curls.append(blob([P(x - r, y), P(x - r * 0.6, y - r * 0.8), P(x, y - r), P(x + r * 0.7, y - r * 0.7),
                           P(x + r, y), P(x + r * 0.5, y + r * 0.6), P(x - r * 0.5, y + r * 0.6)], 0.6))
    out = [lit(ear, WHITE, WHITE_SH, depth=8, line=8)]
    out += [lit(c, GINGER, GINGER_SH, depth=12, line=8) for c in curls[:1] + curls[5:]]
    out.append(lit(face, WHITE, WHITE_SH, depth=18, line=9, air=0.12))
    out += [lit(c, GINGER, GINGER_SH, depth=12, line=8) for c in curls[1:5]]
    out += [ln([P(x, -150), P(x + 20, -120)], w=4.5, color="#e3965c") for x in (-80, 10, 100)]
    # scrunched eyes > <, furrowed brows, tongue out
    out.append(ln([P(-30, -8), P(4, 8), P(-30, 22)], w=10))
    out.append(ln([P(130, -12), P(98, 6), P(130, 20)], w=9))
    out.append(brush([P(-70, -46), P(-30, -40), P(10, -24)], w=15 * s, taper=(0.3, 0.2), color=LINE))
    out.append(brush([P(90, -26), P(124, -44), P(160, -50)], w=14 * s, taper=(0.2, 0.3), color=LINE))
    m = blob([P(30, 110), P(90, 96), P(160, 104), P(150, 140), P(90, 150), P(40, 138)], 0.45)
    out.append(f'<path d="{m}" fill="{MOUTH_IN}" stroke="{LINE}" stroke-width="{7 * s}" stroke-linejoin="round"/>')
    out.append(lit(blob([P(70, 128), P(120, 126), P(132, 176), P(100, 196), P(70, 176)], 0.5), "#e48a90", "#c56a72", depth=6, line=7))
    out.append(ln([P(100, 140), P(102, 176)], w=4, color="#b9555e"))
    return "".join(out)


def kitchen():
    """Crisp, outlined background like a TV cartoon set: lighter and less saturated than the cast."""
    out = ['<rect x="-50" y="-50" width="1180" height="2020" fill="#e9dcc4"/>',
           '<rect x="-50" y="1240" width="1180" height="800" fill="#dccbb0"/>']
    out.append(lit(rrect(90, 170, 560, 500, 10), "#bfe0ea", "#a8cfdb", depth=0, line=7))
    out.append('<path d="M96 520 Q240 470 360 520 T644 506 V664 H96 Z" fill="#cfe3c2"/>')
    out.append(lit(blob([(150, 520), (150, 420), (210, 370), (270, 420), (270, 520)], 0.1), "#f3eee4", "#d9d2c4", depth=8, line=6))
    out.append(lit(blob([(440, 500), (460, 400), (540, 360), (610, 410), (620, 500)], 0.6), "#8fb879", "#76a062", depth=10, line=6))
    out.append(lit(rrect(70, 150, 600, 540, 14), "none", "none", depth=0, line=7).replace('fill="none"', 'fill="none"'))
    out.append('<rect x="70" y="150" width="600" height="540" rx="14" fill="none" stroke="#9a7254" stroke-width="22"/>')
    out.append('<rect x="59" y="139" width="622" height="562" rx="18" fill="none" stroke="#3b3536" stroke-width="7"/>')
    out.append('<rect x="359" y="160" width="22" height="520" fill="#9a7254" stroke="#3b3536" stroke-width="6"/>')
    out.append(lit(rrect(40, 700, 660, 44, 10), "#b58763", "#93684a", depth=8, line=7))
    out.append(lit(rrect(740, 80, 360, 560, 16), "#9cb8ae", "#83a196", depth=14, line=7))
    out.append('<path d="M920 100 V620" stroke="#3b3536" stroke-width="6"/>')
    out.append('<circle cx="895" cy="420" r="11" fill="#e7c16b" stroke="#3b3536" stroke-width="5"/><circle cx="945" cy="420" r="11" fill="#e7c16b" stroke="#3b3536" stroke-width="5"/>')
    pts = [(-40 + i * 80, 130 + 60 * (1 - ((i - 7) / 7) ** 2)) for i in range(15)]
    out.append('<path d="M' + ' L'.join(f'{x:.0f} {y:.0f}' for x, y in pts) + '" fill="none" stroke="#3b3536" stroke-width="5"/>')
    for i, (x, y) in enumerate(pts[1::2]):
        col = ["#ffd36b", "#ff9f6b", "#ffe8a3"][i % 3]
        out.append(f'<circle cx="{x:.0f}" cy="{y + 26:.0f}" r="30" fill="{col}" opacity="0.35"/>')
        out.append(f'<ellipse cx="{x:.0f}" cy="{y + 26:.0f}" rx="12" ry="16" fill="{col}" stroke="#3b3536" stroke-width="5"/>')
    return "".join(out)


def friend_body():
    body = blob([(-80, 2000), (-60, 1560), (0, 1380), (120, 1300), (300, 1290), (430, 1350), (500, 1520), (520, 2000)], 0.5)
    collar = blob([(70, 1330), (160, 1290), (300, 1290), (380, 1330), (300, 1360), (160, 1362)], 0.5)
    out = [lit(body, PURPLE, PURPLE_SH, depth=36, line=9, air=0.3), lit(collar, PURPLE_SH, PURPLE_DK, depth=8, line=7)]
    for x in range(110, 360, 30):
        out.append(ln([(x, 1306 + (x - 230) ** 2 / 900), (x + 4, 1346 + (x - 230) ** 2 / 1100)], w=3.5, color=PURPLE_DK))
    out.append(ln([(60, 1560), (110, 1650), (100, 1780)], w=5.5, color=PURPLE_DK))
    return "".join(out)


def scene():
    set_light(-1, -0.7)
    out0 = [kitchen(), '<g transform="translate(-30 -20)">' + friend_body() + friend_head(230, 1120, 0.95) + '</g>']
    torso = blob([(0, 2000), (20, 1480), (80, 1250), (220, 1120), (420, 1070), (640, 1070), (840, 1120), (960, 1260),
                  (1040, 1480), (1080, 2000)], 0.5)
    hood_back = blob([(200, 1150), (240, 1010), (380, 950), (560, 940), (740, 960), (860, 1040), (880, 1150), (760, 1110), (540, 1100), (330, 1110)], 0.5)
    hood_rim = blob([(250, 1130), (330, 1060), (470, 1040), (640, 1046), (790, 1080), (840, 1140), (760, 1190), (600, 1220), (430, 1214), (300, 1190)], 0.5)
    hood_in = blob([(330, 1150), (420, 1112), (560, 1104), (700, 1114), (762, 1150), (700, 1140), (560, 1132), (420, 1138)], 0.5)
    out = [lit(hood_back, HOOD_SH, HOOD_DK, depth=12, line=9), lit(torso, HOOD, HOOD_SH, depth=44, line=9, air=0.3),
           lit(hood_rim, HOOD, HOOD_SH, depth=14, line=8), lit(hood_in, HOOD_DK, "#21423f", depth=8, line=6)]
    for c in ([(250, 1420), (300, 1520), (296, 1660)], [(820, 1380), (790, 1500), (806, 1640)], [(420, 1300), (470, 1340), (520, 1336)]):
        out.append(ln(c, w=5.5, color=HOOD_DK))
    out.append(ln([(450, 1200), (440, 1330), (452, 1440)], w=11, color="#efece6"))
    out.append(ln([(610, 1204), (626, 1320), (618, 1420)], w=11, color="#efece6"))
    out.append(lit(rrect(436, 1430, 28, 44, 9), "#efece6", "#cfcac2", depth=4, line=5.5))
    out.append(lit(rrect(606, 1410, 28, 44, 9), "#efece6", "#cfcac2", depth=4, line=5.5))
    out.append(head(470, 846, 1.32, "grin"))
    # raised right arm presenting the bottle beside his face
    out.append(sleeve((880, 1230), (1000, 960), 190, 170, folds=2, cuff=False))
    out.append(sleeve((1000, 960), (900, 700), 170, 146, folds=3, cuff=True))
    out.append(bottle(880, 520, 1.25, angle=12))
    out.append(glove_hold(890, 664, 1.32, angle=-8, flip=True))
    return "\n".join(out0) + '<g transform="translate(120 150) scale(0.9)">' + "\n".join(out) + "</g>"


def page():
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
    html,body{{margin:0;width:1080px;height:1920px;overflow:hidden;background:#cfe0e4}}
    svg{{position:absolute;left:0;top:0;width:1080px;height:1920px}}
    @font-face {{ font-family: "Lilita One"; src: url("../assets/fonts/LilitaOne-Regular.ttf"); }}
    .cap {{ position:absolute; left:0; right:0; top:1180px; text-align:center; padding:0 90px; font-family:"Lilita One";
           font-size:100px; line-height:1.02; color:#fff8ec; }}
    .cap span {{ display:inline-block; -webkit-text-stroke: 15px #2a1a14; paint-order: stroke fill; text-shadow: 0 10px 0 #2a1a14; }}
    .cap .key {{ color:#ffcf3f; }}</style></head><body>
    <svg viewBox="0 0 1080 1920" xmlns="http://www.w3.org/2000/svg"><defs>{defs_common()}</defs>
    <rect width="1080" height="1920" fill="#d9e6e8"/>
    {scene()}
    </svg>
    <div class="cap"><span>IF YOUR</span> <span class="key">FRIEND</span></div></body></html>"""


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(root, "stills", "rudy2.html"), "w") as fh:
        fh.write(page())
    print("wrote stills/rudy2.html")
