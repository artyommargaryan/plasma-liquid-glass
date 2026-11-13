# Regenerates the menu frame of a Kvantum theme SVG (menu-normal-* and menu-shadow-* pieces) with corner radius R.
# Kvantum draws a composited menu from the menu-shadow-* tiles: SH px of shadow, then the frame itself.
# usage: kv_menu.py R in.svg out.svg [borderOpacity outlineOpacity SH]
#
# Known good set (Kvantum 1.x, Plasma 6.8), giving a 10px corner on screen:
#   kv_menu.py 8 in.svg out.svg 0 0 4
#   .kvconfig: [Menu] frame.top/bottom/left/right=15, menu_blur_radius=10, reduce_menu_opacity=0
#   kwinrc [Effect-better-blur-dx]: MenuCornerRadius=10, MenuEdgeLine=40
# Why these numbers: Kvantum stretches the R+SH tile to the frame size (12 -> 15, x1.25), so 8/4 in the art are
# 10/5 on screen, and with this tile it starts the blur 6px in, right behind the 1px outline. Other tile sizes
# move the blur start by a pixel; check with WAYLAND_DEBUG=1 (ext_background_effect set_blur_region) after changes.
import os, re, sys
START = float(os.environ.get('KV_START', '0.8'))   # how far outside the corner arc the make-up layer begins; keeps it off the edge line
# Translucency of the menu body, baked into the art. Use with reduce_menu_opacity=0 in the .kvconfig: that option
# fades everything inside a square-cornered rectangle, shadow included, which leaves pale wedges at round corners.
SHADOW = os.environ.get('KV_SHADOW', '0.1')   # darkest point of the drop shadow, right at the menu edge
FILLOP = os.environ.get('KV_FILLOP', '0.2')
BOOST = os.environ.get('KV_BOOST', '0')   # strength of the make-up shadow layer in the faded corner zone (0 = none)
R = float(sys.argv[1]); src, dst = sys.argv[2], sys.argv[3]
BORDER = sys.argv[4] if len(sys.argv) > 4 else '0.35'; OUTLINE = sys.argv[5] if len(sys.argv) > 5 else '0.4'
SH = float(sys.argv[6]) if len(sys.argv) > 6 else 5.0; T = R + SH; L = 50.0
s = open(src).read()
def elem_span(s, i):
    m = re.search(r'<(\w+)\b[^>]*\bid="%s"[^>]*?(/>|>)' % re.escape(i), s, re.S)
    if not m: raise SystemExit('missing id ' + i)
    if m.group(2) == '/>': return m.start(), m.end()
    tag = m.group(1); depth = 0
    for t in re.finditer(r'<(/?)%s\b[^>]*?(/?)>' % tag, s[m.start():], re.S):
        if t.group(1): depth -= 1
        elif not t.group(2): depth += 1
        if depth == 0: return m.start(), m.start() + t.end()
m = re.search(r'<path[^>]*id="menu-normal"[^>]*>', s, re.S); FILL = re.search(r'fill:(#[0-9a-fA-F]{6})', m.group(0)).group(1)
f = lambda v: ('%.4f' % v).rstrip('0').rstrip('.')
names = ['topleft', 'topright', 'bottomright', 'bottomleft']
def arc_pts(cx, cy, r, q): return [((cx-r, cy), (cx, cy-r)), ((cx, cy-r), (cx+r, cy)), ((cx+r, cy), (cx, cy+r)), ((cx, cy+r), (cx-r, cy))][q]
def quarter(cx, cy, r, q):
    (ax, ay), (bx, by) = arc_pts(cx, cy, r, q); return 'M %s,%s A %s %s 0 0 1 %s,%s L %s,%s Z' % (f(ax), f(ay), f(r), f(r), f(bx), f(by), f(cx), f(cy))
def ring(cx, cy, ro, ri, q):
    (ax, ay), (bx, by) = arc_pts(cx, cy, ro, q); (ex, ey), (dx, dy) = arc_pts(cx, cy, ri, q)
    return 'M %s,%s A %s %s 0 0 1 %s,%s L %s,%s A %s %s 0 0 0 %s,%s Z' % (f(ax), f(ay), f(ro), f(ro), f(bx), f(by), f(dx), f(dy), f(ri), f(ri), f(ex), f(ey))
P = lambda d, st: '<path style="%s" d="%s" />' % (st, d)
RC = lambda x, y, w, h, st: '<rect style="%s" x="%s" y="%s" width="%s" height="%s" />' % (st, f(x), f(y), f(w), f(h))
G = lambda i, body: '<g id="%s">%s</g>' % (i, ''.join(body))
fill = 'fill:%s;fill-opacity:%s' % (FILL, FILLOP); border = 'opacity:%s;fill:#ffffff' % BORDER; outline = ('opacity:%s;fill:#ffffff' % OUTLINE[1:]) if OUTLINE[0] == 'w' else ('opacity:%s;fill:#000000' % OUTLINE)   # 'w0.3' = light line, '0.4' = dark line
defs = []; repl = {}
def build(prefix, X, Y, shadow):
    t = T if shadow else R
    x0, y0, x1, y1 = X + t, Y + t, X + t + L, Y + t + L          # inner rectangle; circle centres are its corners
    cs = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    for q, n in enumerate(names):
        cx, cy = cs[q]; body = []
        bx, by = (cx - t if q in (0, 3) else cx), (cy - t if q in (0, 1) else cy)
        if shadow:
            gid = 'glassMenuShadow%d' % q
            defs.append('<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" fx="%s" fy="%s" r="%s"><stop offset="0" style="stop-color:#000000;stop-opacity:0" /><stop offset="%s" style="stop-color:#000000;stop-opacity:0" /><stop offset="%s" style="stop-color:#000000;stop-opacity:SHADOWOP" /><stop offset="1" style="stop-color:#000000;stop-opacity:0" /></radialGradient>' % (gid, f(cx), f(cy), f(cx), f(cy), f(T), f((R - 0.01) / T), f(R / T)))
            body += [RC(bx, by, t, t, 'fill:url(#%s)' % gid), P(ring(cx, cy, R + 1, R, q), outline)]
            # Kvantum fades (reduce_menu_opacity) everything inside the plain rectangle SH px in from the menu
            # surface - square corners. The part of the shadow between the round corner and that square corner
            # would all but vanish, so it gets a second, much stronger layer there to make up for the fade.
            gid2 = 'glassMenuShadowB%d' % q
            defs.append('<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" fx="%s" fy="%s" r="%s"><stop offset="0" style="stop-color:#000000;stop-opacity:0" /><stop offset="%s" style="stop-color:#000000;stop-opacity:0" /><stop offset="%s" style="stop-color:#000000;stop-opacity:%s" /><stop offset="%s" style="stop-color:#000000;stop-opacity:%s" /><stop offset="%s" style="stop-color:#000000;stop-opacity:%s" /><stop offset="1" style="stop-color:#000000;stop-opacity:0" /></radialGradient>' % (gid2, f(cx), f(cy), f(cx), f(cy), f(T), f((R + START - 0.1) / T), f((R + START) / T), BOOST, f((R + 0.6 * SH) / T), BOOST, f((R + 0.8 * SH) / T), f(0.44 * float(BOOST))))
            body.append(RC(cx - R if q in (0, 3) else cx, cy - R if q in (0, 1) else cy, R, R, 'fill:url(#%s)' % gid2))
        body += [P(quarter(cx, cy, R, q), fill), P(ring(cx, cy, R, R - 1, q), border), RC(bx, by, t, t, 'fill:none')]
        repl[prefix + n] = G(prefix + n, body)
    for n, x, y, w, h in (('top', x0, Y, L, t), ('bottom', x0, y1, L, t), ('left', X, y0, t, L), ('right', x1, y0, t, L)):
        body = []
        def strip(a, b, st):   # band between distances a..b from the menu-side edge of the piece, measured outward
            if n == 'top':    return RC(x, y + h - b, w, b - a, st)
            if n == 'bottom': return RC(x, y + a, w, b - a, st)
            if n == 'left':   return RC(x + w - b, y, b - a, h, st)
            return RC(x + a, y, b - a, h, st)
        if shadow:
            gid = 'glassMenuShadowE%s' % n
            ends = {'top': (x, y + SH, x, y), 'bottom': (x, y + h - SH, x, y + h), 'left': (x + SH, y, x, y), 'right': (x + w - SH, y, x + w, y)}[n]
            defs.append('<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s"><stop offset="0" style="stop-color:#000000;stop-opacity:SHADOWOP" /><stop offset="1" style="stop-color:#000000;stop-opacity:0" /></linearGradient>' % ((gid,) + tuple(f(v) for v in ends)))
            body += [strip(R, T, 'fill:url(#%s)' % gid), strip(R, R + 1, outline)]
        body += [strip(0, R, fill), strip(R - 1, R, border)]
        repl[prefix + n] = G(prefix + n, body)
build('menu-shadow-', 3000.0, 500.0, True)
build('menu-normal-', 3200.0, 500.0, False)
# pieces that are <use> references must go before the elements they point at
keys = sorted(repl, key=lambda k: 0 if s[elem_span(s, k)[0]:elem_span(s, k)[0] + 4] == '<use' else 1)
for k in keys:
    st, en = elem_span(s, k); s = s[:st] + repl[k] + s[en:]
defs = [d.replace('SHADOWOP', SHADOW) for d in defs]
s = re.sub(r'<(radial|linear)Gradient id="glassMenuShadow.*?</\1Gradient>', '', s, flags=re.S)
i = s.index('</defs>'); s = s[:i] + ''.join(defs) + s[i:]
a, b = elem_span(s, 'menu-normal'); el = s[a:b]
el = re.sub(r'fill-opacity:[0-9.]+', 'fill-opacity:%s' % FILLOP, el) if 'fill-opacity' in el else el.replace('fill:', 'fill-opacity:%s;fill:' % FILLOP, 1)
s = s[:a] + el + s[b:]
open(dst, 'w').write(s); print('ok R=%g SH=%g fill=%s' % (R, SH, FILL))
