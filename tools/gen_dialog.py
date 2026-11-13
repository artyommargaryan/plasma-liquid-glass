import re, sys, gzip
R = float(sys.argv[1]); src, dst = sys.argv[2], sys.argv[3]
MASK_INSET = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5   # how far the blur stays inside the corner curve
M = 12.0   # shadow margin, matches shadow-hint-*-margin
s = open(src).read()
def elem_span(s, i):
    m = re.search(r'<(\w+)\b[^>]*\bid="%s"[^>]*?(/>|>)' % re.escape(i), s, re.S)
    if not m: raise SystemExit("missing id " + i)
    if m.group(2) == '/>': return m.start(), m.end()
    e = s.index('</%s>' % m.group(1), m.start())
    return m.start(), e + len(m.group(1)) + 3
def style_of(pattern):
    m = re.search(pattern, s);
    if not m: raise SystemExit("style not found: " + pattern)
    return m.group(0)
FILL = style_of(r'opacity:[0-9.]+;fill:#(?!ffffff|000000)[0-9a-f]{6}')   # tint
BORDER = style_of(r'opacity:[0-9.]+;fill:#ffffff')                      # inner light line
OUTLINE = style_of(r'opacity:0\.[0-9]+;fill:#000000')                   # outer dark line
SHADOW_OPACITY = re.search(r'opacity:([0-9.]+);fill:url\(#', s).group(1)
f = lambda v: ('%.4f' % v).rstrip('0').rstrip('.')
def arc_pts(cx, cy, r, q):
    # quarter q: 0=topleft 1=topright 2=bottomright 3=bottomleft; returns start, end (clockwise)
    return [((cx-r, cy), (cx, cy-r)), ((cx, cy-r), (cx+r, cy)), ((cx+r, cy), (cx, cy+r)), ((cx, cy+r), (cx-r, cy))][q]
def quarter(cx, cy, r, q):          # filled quarter disc
    (ax, ay), (bx, by) = arc_pts(cx, cy, r, q)
    return 'M %s,%s A %s %s 0 0 1 %s,%s L %s,%s Z' % (f(ax), f(ay), f(r), f(r), f(bx), f(by), f(cx), f(cy))
def ring(cx, cy, r_out, r_in, q):   # quarter annulus
    (ax, ay), (bx, by) = arc_pts(cx, cy, r_out, q); (cx2, cy2), (dx, dy) = arc_pts(cx, cy, r_in, q)
    return 'M %s,%s A %s %s 0 0 1 %s,%s L %s,%s A %s %s 0 0 0 %s,%s Z' % (f(ax), f(ay), f(r_out), f(r_out), f(bx), f(by), f(dx), f(dy), f(r_in), f(r_in), f(cx2), f(cy2))
path = lambda d, st: '<path style="%s" d="%s" />' % (st, d)
rect = lambda x, y, w, h, st: '<rect style="%s" x="%s" y="%s" width="%s" height="%s" />' % (st, f(x), f(y), f(w), f(h))
group = lambda i, body: '<g id="%s">%s</g>' % (i, ''.join(body))
names = ['topleft', 'topright', 'bottomright', 'bottomleft']
def frame(prefix, x0, y0, C, mask):
    x1, y1 = x0 + C, y0 + C
    centres = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    out = {}
    for q, n in enumerate(names):
        cx, cy = centres[q]
        if mask:
            # keep the blur just inside the fill so the 1px dark outline around the corner sits
            # on the same unblurred backdrop as the outline along the straight edges
            body = [path(quarter(cx, cy, R - MASK_INSET, q), 'fill:#000000')]
        else:
            body = [path(quarter(cx, cy, R, q), FILL)]
        if not mask: body.append(path(ring(cx, cy, R, R - 1, q), BORDER))
        # invisible box so the element is exactly R x R
        bx, by = (cx - R if q in (0, 3) else cx), (cy - R if q in (0, 1) else cy)
        body.append(rect(bx, by, R, R, 'fill:none'))
        out[n] = group(prefix + n, body)
    edges = {'top': (x0, y0 - R, C, R, (x0, y0 - R, C, 1)), 'bottom': (x0, y1, C, R, (x0, y1 + R - 1, C, 1)),
             'left': (x0 - R, y0, R, C, (x0 - R, y0, 1, C)), 'right': (x1, y0, R, C, (x1 + R - 1, y0, 1, C))}
    for n, (x, y, w, h, b) in edges.items():
        body = [rect(x, y, w, h, 'fill:#000000' if mask else FILL)]
        if not mask: body.append(rect(*b, BORDER))
        out[n] = group(prefix + n, body)
    out['center'] = '<rect id="%scenter" style="%s" x="%s" y="%s" width="%s" height="%s" />' % (prefix, 'fill:#000000' if mask else FILL, f(x0), f(y0), f(C), f(C))
    return out
def shadow_corners(x0, y0, C):
    x1, y1 = x0 + C, y0 + C; S = M + R
    centres = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    out, defs = {}, []
    for q, n in enumerate(names):
        cx, cy = centres[q]
        sx, sy = (-1 if q in (0, 3) else 1), (-1 if q in (0, 1) else 1)
        ox, oy = cx + sx * S, cy + sy * S            # outer corner of the tile
        (ax, ay), (bx, by) = arc_pts(cx, cy, R, q)
        # tile square minus the quarter disc of the dialog itself
        if q in (0, 2):
            d = 'M %s,%s L %s,%s L %s,%s L %s,%s A %s %s 0 0 0 %s,%s Z' % (f(ax + sx * M), f(ay), f(ox), f(oy), f(bx), f(by + sy * M), f(bx), f(by), f(R), f(R), f(ax), f(ay))
            d = 'M %s,%s L %s,%s L %s,%s L %s,%s L %s,%s A %s %s 0 0 0 %s,%s Z' % (f(ax), f(ay), f(ox), f(ay), f(ox), f(oy), f(bx), f(oy), f(bx), f(by), f(R), f(R), f(ax), f(ay))
        else:
            d = 'M %s,%s L %s,%s L %s,%s L %s,%s L %s,%s A %s %s 0 0 0 %s,%s Z' % (f(ax), f(ay), f(ax), f(oy), f(ox), f(oy), f(ox), f(by), f(bx), f(by), f(R), f(R), f(ax), f(ay))
        gid = 'glassShadowGrad%d' % q
        defs.append('<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" fx="%s" fy="%s" r="%s"><stop offset="%s" style="stop-color:#000000;stop-opacity:0.27" /><stop offset="%s" style="stop-color:#000000;stop-opacity:0" /></radialGradient>' % (gid, f(cx), f(cy), f(cx), f(cy), f(S), f((R + 1) / S), f((R + 10.5) / S)))
        body = [path(d, 'opacity:%s;fill:url(#%s)' % (SHADOW_OPACITY, gid)), path(ring(cx, cy, R + 1, R, q), OUTLINE),
                rect(min(cx, ox), min(cy, oy), S, S, 'fill:none')]
        out[n] = group('shadow-' + n, body)
    return out, defs
repl = {}
repl.update({k: v for k, v in frame('', 34.0, 18.0, 20.0, False).items()})
repl.update({'mask-' + k: v for k, v in frame('mask-', 104.0, 18.0, 20.0, True).items()})
sh, defs = shadow_corners(34.0, 18.0, 20.0)
repl.update({'shadow-' + k: v for k, v in sh.items()})
# replace corners that are <use> references before the elements they reference
order = sorted(repl, key=lambda k: 0 if any(k.endswith(n) for n in ('topright', 'bottomright', 'bottomleft')) else 1)
for k in order:
    st, en = elem_span(s, k); s = s[:st] + repl[k] + s[en:]
s = re.sub(r'<radialGradient id="glassShadowGrad\d".*?</radialGradient>', '', s, flags=re.S)
i = s.index('</defs>'); s = s[:i] + ''.join(defs) + s[i:]
# the top shadow edge carries its outline opacity in a bare style; keep it in step with the others
s = s.replace('style="opacity:0.75"', 'style="%s"' % OUTLINE.split(';')[0])
gzip.open(dst, 'wb').write(s.encode())
print('ok R=%g' % R, '|', FILL, '|', BORDER, '|', OUTLINE)
