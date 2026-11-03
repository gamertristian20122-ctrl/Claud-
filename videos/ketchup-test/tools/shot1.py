#!/usr/bin/env python3
"""Style frame / shot 1: low-angle party shot, Rudy squirts ketchup on his ice cream."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ink import INK, blob, brush, defs_common, ell, gloss, glove, limb, lit, rrect, set_light  # noqa: E402

# palette (cool purple-teal shadows, warm light)
SKIN, SKIN_SH = "#fbf6ee", "#d9cfd6"
HOOD, HOOD_SH, HOOD_DK = "#2f8c8a", "#1f6670", "#17505b"
CAP, CAP_SH = "#efb042", "#c4802f"
HAIR, HAIR_SH = "#4a2c22", "#2e1a16"
RED, RED_SH, RED_HI = "#e0362b", "#a9201f", "#ff8a6e"
MOUTH, TONGUE = "#5b1f2a", "#ef7f86"


def background():
    set_light(-1, -0.8)
    lights = []
    # string lights along a sagging wire
    pts = [(-60 + i * 74, 250 + 70 * (1 - ((i - 8) / 8) ** 2)) for i in range(17)]
    wire = "M" + " L".join(f"{x:.0f} {y:.0f}" for x, y in pts)
    for i, (x, y) in enumerate(pts[1::2]):
        col = ["#ffd36b", "#ff9f6b", "#ffe8a3"][i % 3]
        lights.append(f'<circle cx="{x:.0f}" cy="{y + 22:.0f}" r="34" fill="{col}" opacity="0.55" filter="url(#soft16)"/>'
                      f'<ellipse cx="{x:.0f}" cy="{y + 22:.0f}" rx="11" ry="15" fill="{col}" stroke="{INK}" stroke-width="4"/>')
    cab = "".join(
        lit(rrect(x, 90, 150, 380, 14), "#7aa7a3", "#5b8584", depth=12, line=6) +
        f'<circle cx="{x + (128 if i == 0 else 22)}" cy="400" r="9" fill="#e9c27a" stroke="{INK}" stroke-width="4"/>'
        for i, x in enumerate((760, 920))
    )
    fridge = lit(rrect(-60, 760, 240, 1200, 30), "#e9e2dc", "#c9c0c8", depth=20, line=7)
    return f"""
      <g id="s1-bg" filter="url(#soft4)">
        <rect x="-200" y="-200" width="1480" height="2400" fill="url(#s1-wall)"/>
        <rect x="40" y="120" width="520" height="560" rx="10" fill="url(#s1-sky)"/>
        <path d="M40 520 Q200 470 330 520 T560 500 V680 H40 Z" fill="#f4b27a" opacity="0.8"/>
        <path d="M90 560 h70 v-60 l40 -34 l40 34 v60 h40" fill="#e79a6c" opacity="0.9"/>
        <rect x="22" y="102" width="556" height="596" rx="16" fill="none" stroke="#6d4230" stroke-width="34"/>
        <rect x="290" y="120" width="22" height="560" fill="#6d4230"/>
        <rect x="40" y="392" width="520" height="20" fill="#6d4230"/>
        <rect x="0" y="690" width="600" height="40" rx="8" fill="#8c5a3e"/>
        <rect x="70" y="640" width="40" height="52" rx="8" fill="#d36f5a"/><path d="M90 640 q-24 -50 -6 -70 q14 26 6 70 q20 -40 40 -46 q-10 30 -40 46" fill="#5d9a5b"/>
        {cab}
        {fridge}
        <rect x="-20" y="870" width="60" height="30" rx="8" fill="#f06a5a" transform="rotate(-8 10 885)"/>
        <rect x="70" y="930" width="50" height="50" rx="25" fill="#5ba7d8"/>
      </g>
      <g id="s1-lights">
        <path d="{wire}" fill="none" stroke="{INK}" stroke-width="5" opacity="0.8"/>
        {''.join(lights)}
      </g>
      <circle cx="250" cy="300" r="360" fill="#fff1c9" opacity="0.55" filter="url(#soft40)"/>
    """


def friend_bg():
    """A friend in the mid-ground, recoiling. Kept soft so focus stays on Rudy."""
    set_light(-1, -0.8)
    head = blob([(120, 1080), (175, 1040), (250, 1050), (285, 1110), (270, 1185), (205, 1220), (140, 1200), (108, 1140)])
    hair = blob([(100, 1110), (118, 1030), (190, 1000), (272, 1030), (300, 1100), (262, 1070), (210, 1062), (150, 1078)])
    body = blob([(40, 1500), (70, 1260), (150, 1215), (260, 1220), (330, 1290), (350, 1500)])
    return f"""
      <g id="s1-pal" filter="url(#soft4)" opacity="0.95" transform="translate(800 -60) scale(0.95)">
        {lit(body, "#8b5fb0", "#65428a", depth=16, line=7)}
        {lit(head, SKIN, SKIN_SH, depth=14, line=7)}
        {lit(hair, "#d4893e", "#a55f2a", depth=10, line=7)}
        {brush([(150, 1120), (175, 1112), (198, 1124)], w=7)}
        {brush([(222, 1118), (246, 1110), (266, 1122)], w=7)}
        <path d="M168 1162 q30 -14 62 0 q-6 26 -30 26 q-26 0 -32 -26z" fill="{MOUTH}" stroke="{INK}" stroke-width="5"/>
        <path d="M190 1176 q12 26 26 4" fill="{TONGUE}" stroke="{INK}" stroke-width="4"/>
        {brush([(140, 1096), (170, 1100)], w=6)}{brush([(236, 1098), (268, 1090)], w=6)}
      </g>
    """


def cone_and_ketchup():
    """Cone held high at upper left, a double scoop drowning in ketchup."""
    set_light(-1, -0.8)
    cone = blob([(250, 560), (420, 560), (350, 820), (325, 830)], 0.3)
    waffle = "".join(brush([(a, 572), (b, 760)], w=4, color="#a86a2c") for a, b in ((270, 370), (310, 400), (350, 420), (290, 260)))
    waffle += "".join(brush([(a, 572), (b, 780)], w=4, color="#a86a2c") for a, b in ((400, 320), (370, 290)))
    scoop1 = blob([(240, 560), (250, 500), (300, 470), (370, 468), (425, 500), (432, 560), (400, 585), (360, 570), (330, 590), (290, 572), (260, 590)])
    scoop2 = blob([(262, 470), (270, 410), (320, 380), (380, 388), (412, 430), (408, 476), (380, 490), (340, 482), (300, 492)])
    ketchup = blob([(250, 420), (262, 380), (300, 352), (350, 340), (398, 356), (420, 392), (414, 430), (404, 470), (392, 430), (370, 440), (352, 500), (336, 444), (300, 440), (282, 476), (266, 432)])
    drops = "".join(f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r * 1.3:.0f}" fill="{RED}" stroke="{INK}" stroke-width="4"/>'
                    for x, y, r in ((236, 520, 9), (446, 470, 7), (270, 610, 6)))
    return f"""
      <g id="s1-cone">
        {lit(cone, "#e9a85b", "#b9773a", depth=18, line=8)}
        {waffle}
        {lit(scoop1, "#fff0d8", "#e2c9b6", depth=16, line=8)}
        {lit(scoop2, "#f7a8bf", "#d77d9c", depth=14, line=8)}
        {lit(ketchup, RED, RED_SH, depth=12, line=8)}
        {gloss([(292, 372), (330, 356), (360, 358)], w=12)}
        {gloss([(372, 410), (382, 446)], w=8, opacity=0.6)}
        {drops}
      </g>
    """


def bottle_svg():
    """Glossy squeeze bottle in its own frame: nozzle toward -y, grip point at (0,0)."""
    set_light(-1, -0.8)
    body = rrect(-58, -170, 116, 230, 44)
    cap = rrect(-40, -206, 80, 44, 12)
    nozzle = blob([(-16, -204), (16, -204), (8, -244), (-8, -244)], 0.2)
    label = ell(0, -70, 42, 52)
    return f"""
        {lit(nozzle, "#f8f4ec", "#cfc8cf", depth=5, line=6)}
        {lit(cap, "#f8f4ec", "#cfc8cf", depth=8, line=7)}
        {lit(body, RED, RED_SH, depth=20, line=8)}
        {gloss([(-36, -150), (-40, -60), (-34, 20)], w=16, opacity=0.55)}
        {gloss([(30, -140), (34, -110)], w=8, opacity=0.4)}
        {lit(label, "#fbecc9", "#e2c99c", depth=8, line=5)}
        <circle cx="0" cy="-64" r="22" fill="{RED}" stroke="{INK}" stroke-width="4"/>
        <path d="M-2 -86 q-14 -12 -22 -2 q12 0 22 2 q10 -12 22 -2 q-12 0 -22 2z" fill="#4f9a49" stroke="{INK}" stroke-width="3"/>
    """


def ik2(S, T, L1, L2, bend=1):
    import math
    dx, dy = T[0] - S[0], T[1] - S[1]
    d = min(L1 + L2 - 1, max(abs(L1 - L2) + 1, math.hypot(dx, dy)))
    a = math.atan2(dy, dx)
    k = math.acos((L1 * L1 + d * d - L2 * L2) / (2 * L1 * d))
    e = (S[0] + L1 * math.cos(a + bend * k), S[1] + L1 * math.sin(a + bend * k))
    return e


def glove_grip(cx, cy, s=1.0, angle=0, flip=False):
    """Gloved fist wrapped around a handle that runs along local y through (0,0)."""
    sx = -1 if flip else 1
    def P(x, y):
        return (x * s * sx, y * s)
    back = blob([P(-46, -40), P(30, -52), P(56, -10), P(52, 40), P(10, 58), P(-44, 44), P(-58, 0)], 0.55)
    rolls = "".join(lit(blob([P(4, y - 15), P(58, y - 17), P(68, y), P(58, y + 15), P(4, y + 14)], 0.5),
                        "#ffffff", "#d6d0e0", depth=6, line=6) for y in (-30, -2, 26))
    thumb = blob([P(-40, -46), P(-6, -70), P(24, -62), P(10, -40), P(-30, -26)], 0.5)
    cuff = blob([P(-62, -30), P(-40, -64), P(-20, -56), P(-44, -18)], 0.5)
    return (f'<g transform="translate({cx} {cy}) rotate({angle})">'
            + lit(back, "#ffffff", "#d6d0e0", depth=10, line=7) + rolls
            + lit(thumb, "#ffffff", "#d6d0e0", depth=6, line=6) + "</g>")


def crease(E, H):
    """Two short fold lines just past the elbow, across the sleeve."""
    import math
    dx, dy = H[0] - E[0], H[1] - E[1]
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux
    out = ""
    for t, w in ((38, 0.7), (70, 0.5)):
        cx, cy = E[0] + ux * t, E[1] + uy * t
        out += brush([(cx + nx * 40 * w, cy + ny * 40 * w), (cx + ux * 10, cy + uy * 10), (cx - nx * 10 * w, cy - ny * 10 * w)], w=6, color=HOOD_DK)
    return out


def rudy():
    set_light(-1, -0.8)
    # ---- torso with real shoulders; hoodie, hood bunched behind the neck
    torso = blob([(40, 2000), (60, 1480), (110, 1270), (210, 1150), (360, 1100), (520, 1095), (680, 1130),
                  (790, 1240), (850, 1450), (880, 2000)], 0.5)
    hood = blob([(230, 1150), (300, 1080), (430, 1050), (560, 1060), (650, 1110), (600, 1160), (440, 1170), (300, 1180)])
    pocket = blob([(200, 1640), (640, 1630), (700, 1900), (150, 1910)], 0.25)
    folds = "".join([
        brush([(170, 1380), (230, 1470), (240, 1590)], w=8, color=HOOD_DK),
        brush([(700, 1330), (680, 1450), (700, 1560)], w=8, color=HOOD_DK),
        brush([(330, 1620), (420, 1600), (520, 1615)], w=6, color=HOOD_DK),
    ])
    strings = (brush([(380, 1170), (370, 1270), (382, 1360)], w=10, color="#f2ede4") +
               brush([(480, 1172), (494, 1260), (486, 1340)], w=10, color="#f2ede4") +
               f'<rect x="370" y="1350" width="22" height="34" rx="6" fill="#f2ede4" stroke="{INK}" stroke-width="5"/>'
               f'<rect x="475" y="1330" width="22" height="34" rx="6" fill="#f2ede4" stroke="{INK}" stroke-width="5"/>')

    # ---- head: three-quarter view facing right, looking up at the cone
    face = blob([(250, 880), (265, 770), (330, 700), (440, 680), (550, 700), (630, 760), (660, 860), (640, 980),
                 (580, 1060), (470, 1095), (360, 1080), (285, 1010)], 0.55)
    ear = blob([(282, 880), (232, 856), (206, 905), (222, 968), (276, 980)])
    band = blob([(244, 860), (270, 770), (420, 732), (590, 748), (668, 800), (672, 856), (600, 820), (430, 806), (290, 840), (250, 900)], 0.45)
    dome = blob([(262, 790), (280, 690), (350, 610), (460, 585), (570, 610), (640, 690), (664, 800), (500, 760), (330, 780)], 0.5)
    pom = blob([(430, 560), (450, 520), (490, 512), (520, 530), (530, 568), (510, 600), (470, 606), (440, 590)], 0.6)
    ribs = "".join(brush([(x, 768 + (x - 450) ** 2 / 3000), (x + 6, 820 + (x - 450) ** 2 / 4000)], w=5, color="#9a5f25")
                   for x in range(300, 660, 44))
    tuft_l = blob([(246, 860), (270, 840), (296, 868), (278, 900), (300, 930), (262, 930)], 0.5)
    tuft_r = blob([(600, 822), (640, 814), (668, 846), (650, 880), (630, 858)], 0.5)
    eyes = f"""
        <g id="s1-eyes">
          <ellipse cx="440" cy="896" rx="18" ry="28" fill="{INK}" transform="rotate(10 440 896)"/>
          <ellipse cx="560" cy="890" rx="15" ry="24" fill="{INK}" transform="rotate(10 560 890)"/>
          <circle cx="446" cy="884" r="6" fill="#fff"/><circle cx="565" cy="879" r="5" fill="#fff"/>
        </g>"""
    brows = brush([(395, 846), (432, 826), (470, 832)], w=12) + brush([(528, 828), (562, 818), (594, 830)], w=11)
    mouth = blob([(400, 975), (500, 985), (618, 958), (606, 1012), (560, 1052), (480, 1058), (424, 1022)], 0.5)
    tongue = blob([(452, 1036), (510, 1018), (572, 1030), (548, 1054), (482, 1058)], 0.5)
    teeth = f'<path d="M406 978 Q505 996 612 962 L606 980 Q505 1012 414 994 Z" fill="#fff"/>'
    cheek = (f'<ellipse cx="360" cy="975" rx="40" ry="20" fill="#f3a8a0" opacity="0.6"/>'
             f'<ellipse cx="620" cy="960" rx="24" ry="14" fill="#f3a8a0" opacity="0.55"/>')
    nose = brush([(650, 900), (672, 922), (648, 936)], w=7)
    head = f"""
      <g id="s1-head" transform="rotate(-5 450 1090)">
        {lit(ear, SKIN, SKIN_SH, depth=10, line=8)}
        {brush([(232, 900), (220, 925), (236, 950)], w=6)}
        {lit(face, SKIN, SKIN_SH, depth=24, line=9, air=0.3)}
        {cheek}
        {lit(tuft_l, HAIR, HAIR_SH, depth=8, line=7)}
        {lit(tuft_r, HAIR, HAIR_SH, depth=8, line=7)}
        {lit(dome, CAP, CAP_SH, depth=22, line=9)}
        {lit(band, CAP_SH, "#9a5f25", depth=12, line=9)}
        {ribs}
        {gloss([(330, 690), (400, 640), (470, 628)], w=16, opacity=0.45)}
        {lit(pom, "#f6e7c8", "#d8c2a0", depth=10, line=8)}
        {brows}
        {eyes}
        {nose}
        <path d="{mouth}" fill="{MOUTH}" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>
        {teeth}
        <path d="{tongue}" fill="{TONGUE}"/>
        {brush([(392, 968), (412, 980)], w=6)}
      </g>"""

    # ---- arms: left arm carries the cone across the chest, right arm raises the bottle above it
    L1, L2 = 340, 330
    SL, HL = (180, 1220), (742, 1000)
    SR, HR = (640, 1060), (806, 452)
    EL = ik2(SL, HL, L1, L2, bend=1)
    ER = ik2(SR, HR, L1, L2, bend=-1)
    arm_l = (limb(SL, EL, 150, 132, HOOD, HOOD_SH, line=9) +
             limb(EL, HL, 132, 112, HOOD, HOOD_SH, line=9, cuff=(HOOD_SH, HOOD_DK)) + crease(EL, HL))
    arm_r = (limb(SR, ER, 150, 132, HOOD, HOOD_SH, line=9) +
             limb(ER, HR, 132, 112, HOOD, HOOD_SH, line=9, cuff=(HOOD_SH, HOOD_DK)) + crease(ER, HR))
    cone = f'<g transform="translate(470 360) scale(1.05)">{cone_and_ketchup()}</g>'
    bottle = f'<g transform="translate(810 446) rotate(172) scale(1.0) translate(0 -22)">{bottle_svg()}</g>'
    stream = """
      <path d="M842 668 C846 690 840 712 828 736" fill="none" stroke="#33251e" stroke-width="36" stroke-linecap="round"/>
      <path d="M842 668 C846 690 840 712 828 736" fill="none" stroke="#e0362b" stroke-width="24" stroke-linecap="round"/>
      <path d="M838 676 C840 692 836 706 830 718" fill="none" stroke="#ff9c86" stroke-width="6" stroke-linecap="round" opacity="0.85"/>
    """
    return f"""
      <g id="s1-rudy" filter="url(#wobble)">
        {lit(hood, HOOD_SH, HOOD_DK, depth=14, line=8)}
        {lit(torso, HOOD, HOOD_SH, depth=46, line=10, air=0.38)}
        {lit(pocket, HOOD_SH, HOOD_DK, depth=14, line=8)}
        {folds}
        {strings}
        {head}
        {arm_r}
        {bottle}
        {glove_grip(808, 452, 1.25, angle=-8, flip=True)}
        {stream}
        {arm_l}
        {cone}
        {glove_grip(745, 1000, 1.25, angle=-70)}
      </g>
    """


def foreground():
    fries = "".join(
        f'<rect x="{x}" y="{y}" width="34" height="200" rx="8" fill="#f1c25b" stroke="{INK}" stroke-width="6" transform="rotate({r} {x + 17} {y + 100})"/>'
        for x, y, r in ((40, 1650, -18), (90, 1630, -6), (140, 1660, 10), (10, 1700, -30), (180, 1700, 22))
    )
    return f"""
      <g id="s1-fg" filter="url(#soft16)">
        {fries}
        <path d="M-80 1800 Q160 1740 360 1810 L380 2000 L-80 2000 Z" fill="#d85a4a" stroke="{INK}" stroke-width="8"/>
        <path d="M-80 1800 Q160 1740 360 1810" fill="none" stroke="#f7efe6" stroke-width="18"/>
      </g>
    """


def frame_svg(bg=True, char=True, fg=True, fx=True):
    return f"""
    <svg id="s1-svg" viewBox="0 0 1080 1920" xmlns="http://www.w3.org/2000/svg">
      <defs>
        {defs_common()}
        <linearGradient id="s1-wall" x1="0" y1="0" x2="0.6" y2="1">
          <stop offset="0" stop-color="#f6cf9f"/><stop offset="0.6" stop-color="#e2a377"/><stop offset="1" stop-color="#b77565"/>
        </linearGradient>
        <linearGradient id="s1-sky" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#ffe9ba"/><stop offset="1" stop-color="#ffb877"/>
        </linearGradient>
        <radialGradient id="s1-vig" cx="0.35" cy="0.3" r="0.95">
          <stop offset="0.5" stop-color="#2a1430" stop-opacity="0"/><stop offset="1" stop-color="#2a1430" stop-opacity="0.5"/>
        </radialGradient>
      </defs>
      <g id="s1-cam" transform="rotate(-4 540 900)">
        {background() if bg else ""}
        {friend_bg() if bg else ""}
        {rudy() if char else ""}
        {foreground() if fg else ""}
      </g>
      {'<rect width="1080" height="1920" fill="url(#s1-vig)"/>' if fx else ""}
      {'<rect width="1080" height="1920" filter="url(#grain)" opacity="0.55" style="mix-blend-mode:multiply"/>' if fx else ""}
    </svg>"""


CAPTION_CSS = """
  @font-face { font-family: "Lilita One"; src: url("../assets/fonts/LilitaOne-Regular.ttf"); }
  .cap { position:absolute; left:0; right:0; top:1150px; text-align:center; padding:0 90px;
         font-family:"Lilita One"; font-size:96px; line-height:1.02; color:#fff8ec; letter-spacing:1px; }
  .cap span { display:inline-block; -webkit-text-stroke: 14px #2a1a14; paint-order: stroke fill;
              text-shadow: 0 9px 0 #2a1a14; }
  .cap .key { color:#ffcf3f; }
"""


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.makedirs(os.path.join(root, "stills"), exist_ok=True)
    html = f"""<!doctype html><html><head><meta charset="utf-8"><style>
      html,body{{margin:0;width:1080px;height:1920px;overflow:hidden;background:#000}}
      svg{{position:absolute;left:0;top:0;width:1080px;height:1920px}}
      {CAPTION_CSS}
    </style></head><body>{frame_svg()}
    <div class="cap"><span>IF YOUR</span> <span class="key">FRIEND</span></div></body></html>"""
    with open(os.path.join(root, "stills", "shot1.html"), "w") as fh:
        fh.write(html)
    print("wrote stills/shot1.html")
