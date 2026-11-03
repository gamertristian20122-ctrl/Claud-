"""Hand-inked cartoon drawing helpers (SVG strings).

The look: warm ink lines that swell on the shadow side and taper at the ends,
two-tone cel shading plus a soft airbrush gradient, glossy highlights, and a
shared light direction so every shape in a shot is lit the same way.
"""
import math

INK = "#33251e"
_uid = [0]


def uid(prefix="k"):
    _uid[0] += 1
    return f"{prefix}{_uid[0]}"


def f(x):
    return f"{x:.1f}".rstrip("0").rstrip(".")


# ------------------------------------------------------------------ shapes as path data
def ell(cx, cy, rx, ry):
    return (f"M{f(cx - rx)} {f(cy)} A{f(rx)} {f(ry)} 0 1 0 {f(cx + rx)} {f(cy)} "
            f"A{f(rx)} {f(ry)} 0 1 0 {f(cx - rx)} {f(cy)} Z")


def rrect(x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    return (f"M{f(x + r)} {f(y)} H{f(x + w - r)} Q{f(x + w)} {f(y)} {f(x + w)} {f(y + r)} "
            f"V{f(y + h - r)} Q{f(x + w)} {f(y + h)} {f(x + w - r)} {f(y + h)} H{f(x + r)} "
            f"Q{f(x)} {f(y + h)} {f(x)} {f(y + h - r)} V{f(y + r)} Q{f(x)} {f(y)} {f(x + r)} {f(y)} Z")


def blob(points, tension=0.5):
    """Closed smooth curve through points (Catmull-Rom -> cubic Bezier)."""
    n = len(points)
    d = f"M{f(points[0][0])} {f(points[0][1])} "
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) * tension / 3, p1[1] + (p2[1] - p0[1]) * tension / 3)
        c2 = (p2[0] - (p3[0] - p1[0]) * tension / 3, p2[1] - (p3[1] - p1[1]) * tension / 3)
        d += f"C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])} "
    return d + "Z"


# ------------------------------------------------------------------ brush strokes
def _bez(p0, p1, p2, p3, t):
    u = 1 - t
    return (u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
            u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1])


def _spine(pts, n=24):
    """pts: 2 points (line), 3 (quadratic-ish via midpoint), 4 (cubic) -> sampled polyline."""
    if len(pts) == 2:
        p0, p3 = pts
        p1 = (p0[0] + (p3[0] - p0[0]) / 3, p0[1] + (p3[1] - p0[1]) / 3)
        p2 = (p0[0] + 2 * (p3[0] - p0[0]) / 3, p0[1] + 2 * (p3[1] - p0[1]) / 3)
    elif len(pts) == 3:
        p0, c, p3 = pts
        p1 = (p0[0] + 2 / 3 * (c[0] - p0[0]), p0[1] + 2 / 3 * (c[1] - p0[1]))
        p2 = (p3[0] + 2 / 3 * (c[0] - p3[0]), p3[1] + 2 / 3 * (c[1] - p3[1]))
    else:
        p0, p1, p2, p3 = pts
    return [_bez(p0, p1, p2, p3, i / (n - 1)) for i in range(n)]


def brush(pts, w=8, taper=(0.15, 0.15), color=INK, opacity=1.0, extra=""):
    """A tapered ink stroke: thin at both ends, full width in the middle."""
    sp = _spine(pts)
    n = len(sp)
    left, right = [], []
    for i, (x, y) in enumerate(sp):
        a = sp[max(i - 1, 0)]
        b = sp[min(i + 1, n - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L, dx / L
        t = i / (n - 1)
        k = 1.0
        if t < taper[0]:
            k = 0.25 + 0.75 * (t / taper[0])
        elif t > 1 - taper[1]:
            k = 0.25 + 0.75 * ((1 - t) / taper[1])
        hw = w * k / 2
        left.append((x + nx * hw, y + ny * hw))
        right.append((x - nx * hw, y - ny * hw))
    poly = left + right[::-1]
    d = "M" + " L".join(f"{f(x)} {f(y)}" for x, y in poly) + " Z"
    op = f' opacity="{opacity}"' if opacity != 1 else ""
    return f'<path d="{d}" fill="{color}"{op} stroke="{color}" stroke-width="0.8" stroke-linejoin="round"{extra}/>'


# ------------------------------------------------------------------ lit, inked shapes
LIGHT = (-1.0, -0.8)   # light comes from the upper left unless a shot says otherwise


def set_light(dx, dy):
    global LIGHT
    L = math.hypot(dx, dy)
    LIGHT = (dx / L, dy / L)


def lit(d, base, shade, depth=18, line=8, air=0.22, rim=None,
        rim_depth=7, swell=1.8, extra_inside="", fill_rule="nonzero"):
    """A shape with cel shadow, airbrush falloff, optional highlight and rim light,
    and an outline that is thicker on the side away from the light."""
    cid, mid, gid = uid("c"), uid("m"), uid("g")
    lx, ly = LIGHT
    out = [f'<clipPath id="{cid}"><path d="{d}" clip-rule="{fill_rule}"/></clipPath>']
    # gradient: bright on the lit side, darker on the far side
    x1, y1 = 0.5 + lx * 0.5, 0.5 + ly * 0.5
    x2, y2 = 0.5 - lx * 0.5, 0.5 - ly * 0.5
    out.append(
        f'<linearGradient id="{gid}" x1="{f(x1)}" y1="{f(y1)}" x2="{f(x2)}" y2="{f(y2)}">'
        f'<stop offset="0" stop-color="#ffffff" stop-opacity="0.10"/>'
        f'<stop offset="0.55" stop-color="#000000" stop-opacity="0"/>'
        f'<stop offset="1" stop-color="#1a0f2a" stop-opacity="{air}"/></linearGradient>'
    )
    out.append(f'<path d="{d}" fill="{shade}"/>')
    out.append(f'<g clip-path="url(#{cid})">')
    # the lit face is the same shape nudged toward the light; what it leaves uncovered is shadow
    out.append(f'<path d="{d}" fill="{base}" transform="translate({f(lx * depth)} {f(ly * depth)})"/>')
    out.append(extra_inside)
    out.append(f'<path d="{d}" fill="url(#{gid})"/>')
    if rim:
        out.append(
            f'<mask id="{mid}"><path d="{d}" fill="#fff"/>'
            f'<path d="{d}" fill="#000" transform="translate({f(-lx * rim_depth)} {f(-ly * rim_depth)})"/></mask>'
            f'<path d="{d}" fill="{rim}" mask="url(#{mid})"/>'
        )
    out.append("</g>")
    # ink: a thin line all round, and a heavier one on the shadow side
    swell_mask = uid("s")
    out.append(
        f'<mask id="{swell_mask}"><rect x="-4000" y="-4000" width="9000" height="9000" fill="#fff"/>'
        f'<path d="{d}" fill="#000" transform="translate({f(lx * line * 1.2)} {f(ly * line * 1.2)})"/></mask>'
    )
    out.append(f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{f(line * swell)}" '
               f'stroke-linejoin="round" mask="url(#{swell_mask})"/>')
    out.append(f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{f(line)}" stroke-linejoin="round"/>')
    return "".join(out)


def gloss(pts, w=10, opacity=0.7, color="#ffffff"):
    return brush(pts, w=w, taper=(0.4, 0.4), color=color, opacity=opacity)


# ------------------------------------------------------------------ gloved cartoon hands
def glove(pose="grip", s=1.0, flip=False, base="#ffffff", shade="#d9d4e4", line=7):
    """White cartoon glove centred on the wrist joint (0,0), fingers toward +y.
    Poses: grip (holding something), point, open, thumb (thumbs up, fingers toward -x)."""
    def P(x, y):
        return ((-x if flip else x) * s, y * s)

    parts = []
    cuff = blob([P(-30, -6), P(30, -6), P(34, 14), P(-34, 14)], 0.4)
    if pose == "grip":
        palm = blob([P(-34, 10), P(30, 6), P(44, 40), P(36, 78), P(-6, 92), P(-40, 70), P(-46, 36)], 0.55)
        fingers = [blob([P(x - 13, 52), P(x + 13, 52), P(x + 14, 92), P(x - 12, 94)], 0.6) for x in (-26, 0, 24)]
        thumb = blob([P(-40, 30), P(-62, 46), P(-60, 70), P(-40, 64)], 0.6)
        parts += [lit(palm, base, shade, depth=10, line=line)]
        parts += [lit(fd, base, shade, depth=8, line=line * 0.85) for fd in fingers]
        parts += [lit(thumb, base, shade, depth=8, line=line * 0.85)]
    elif pose == "point":
        palm = blob([P(-34, 10), P(30, 6), P(42, 38), P(30, 74), P(-10, 82), P(-40, 62), P(-44, 32)], 0.55)
        index = blob([P(-12, 60), P(8, 60), P(10, 150), P(-10, 152)], 0.5)
        curled = [blob([P(x - 13, 58), P(x + 13, 56), P(x + 12, 84), P(x - 12, 86)], 0.6) for x in (14, 34)]
        thumb = blob([P(-40, 28), P(-64, 40), P(-62, 62), P(-40, 58)], 0.6)
        parts += [lit(palm, base, shade, depth=10, line=line), lit(index, base, shade, depth=7, line=line * 0.85)]
        parts += [lit(c, base, shade, depth=8, line=line * 0.85) for c in curled]
        parts += [lit(thumb, base, shade, depth=8, line=line * 0.85)]
    elif pose == "open":
        palm = blob([P(-34, 10), P(32, 8), P(44, 46), P(30, 78), P(-24, 80), P(-44, 46)], 0.55)
        fingers = [blob([P(x - 11, 64), P(x + 11, 62), P(x + 10 + x * 0.25, 128), P(x - 10 + x * 0.25, 130)], 0.5)
                   for x in (-28, -8, 12, 32)]
        thumb = blob([P(-38, 26), P(-78, 18), P(-84, 36), P(-44, 54)], 0.6)
        parts += [lit(fd, base, shade, depth=7, line=line * 0.85) for fd in fingers]
        parts += [lit(palm, base, shade, depth=10, line=line), lit(thumb, base, shade, depth=7, line=line * 0.85)]
    elif pose == "thumb":
        fist = blob([P(-36, 8), P(36, 8), P(48, 50), P(38, 90), P(-30, 92), P(-46, 50)], 0.55)
        thumb = blob([P(-20, 10), P(-8, -70), P(14, -72), P(18, 14)], 0.55)
        parts += [lit(thumb, base, shade, depth=7, line=line * 0.85), lit(fist, base, shade, depth=10, line=line)]
        for y in (40, 64):
            parts.append(brush([P(-30, y), P(30, y - 4)], w=5))
    parts.insert(0, lit(cuff, base, shade, depth=6, line=line * 0.9))
    return "".join(parts)


# ------------------------------------------------------------------ sleeves / limbs
def limb(p0, p1, w0, w1, base, shade, line=8, cuff=None):
    """A tapered sleeve segment from p0 to p1 (rounded ends), drawn in its own frame."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy) or 1
    nx, ny = -dy / L, dx / L
    a = (x0 + nx * w0 / 2, y0 + ny * w0 / 2)
    b = (x1 + nx * w1 / 2, y1 + ny * w1 / 2)
    c = (x1 - nx * w1 / 2, y1 - ny * w1 / 2)
    e = (x0 - nx * w0 / 2, y0 - ny * w0 / 2)
    d = (f"M{f(a[0])} {f(a[1])} L{f(b[0])} {f(b[1])} A{f(w1 / 2)} {f(w1 / 2)} 0 0 0 {f(c[0])} {f(c[1])} "
         f"L{f(e[0])} {f(e[1])} A{f(w0 / 2)} {f(w0 / 2)} 0 0 0 {f(a[0])} {f(a[1])} Z")
    out = lit(d, base, shade, depth=w0 * 0.22, line=line)
    if cuff:
        cw = w1 * 1.06
        cx0, cy0 = x1 - dx / L * 26, y1 - dy / L * 26
        cd = (f"M{f(cx0 + nx * cw / 2)} {f(cy0 + ny * cw / 2)} L{f(x1 + nx * cw / 2)} {f(y1 + ny * cw / 2)} "
              f"L{f(x1 - nx * cw / 2)} {f(y1 - ny * cw / 2)} L{f(cx0 - nx * cw / 2)} {f(cy0 - ny * cw / 2)} Z")
        out += lit(cd, cuff[0], cuff[1], depth=6, line=line * 0.8)
    return out


def defs_common():
    """Paper grain + bloom filters shared by every shot."""
    return """
      <filter id="grain" x="0" y="0" width="100%" height="100%">
        <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="7" result="n"/>
        <feColorMatrix type="saturate" values="0"/>
        <feComponentTransfer><feFuncA type="table" tableValues="0 0.22"/></feComponentTransfer>
      </filter>
      <filter id="wobble" x="-5%" y="-5%" width="110%" height="110%">
        <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="3" result="w"/>
        <feDisplacementMap in="SourceGraphic" in2="w" scale="5" xChannelSelector="R" yChannelSelector="G"/>
      </filter>
      <filter id="soft4"><feGaussianBlur stdDeviation="4"/></filter>
      <filter id="soft8"><feGaussianBlur stdDeviation="8"/></filter>
      <filter id="soft16"><feGaussianBlur stdDeviation="16"/></filter>
      <filter id="soft40"><feGaussianBlur stdDeviation="40"/></filter>
    """
