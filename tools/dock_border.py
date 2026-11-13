# Adds a 1px light line all the way round the dock (south-*) pieces of panel-background, corners included.
# The effect's rim light brightens the straight edges (top/left lit, bottom/right weaker) but is clipped at the
# corners by the blur mask, so the corner arcs carry their own brighter line, fading from the lit to the back side.
# The blur mask stops a little short of the corner curve, leaving a sliver where the raw backdrop shows through
# undimmed (a light fleck over light windows); an optional dark ring SHADE_W wide at SHADE_OP covers it.
# usage: dock_border.py R edgeOpacity litOpacity backOpacity in.svgz out.svgz [shadeWidth shadeOpacity]
import re, sys, gzip
R = float(sys.argv[1]); OP, LIT, BACK = sys.argv[2:5]; src, dst = sys.argv[5], sys.argv[6]
SHADE_W = float(sys.argv[7]) if len(sys.argv) > 7 else 0.0; SHADE_OP = sys.argv[8] if len(sys.argv) > 8 else '0'
s = gzip.open(src).read().decode()
if 'dock-border' in s: raise SystemExit('already has a border')
B = 'opacity:%s;fill:#ffffff' % OP
f = lambda v: ('%.4f' % v).rstrip('0').rstrip('.')
def edge(m):
    n = m.group(1); a = dict(re.findall(r'(x|y|width|height)="([^"]+)"', m.group(0)))
    x, y, w, h = (float(a[k]) for k in ('x', 'y', 'width', 'height'))
    b = {'top': (x, y, w, 1), 'bottom': (x, y + h - 1, w, 1), 'left': (x, y, 1, h), 'right': (x + w - 1, y, 1, h)}[n]
    plain = m.group(0).replace(' id="south-%s"' % n, '')
    return '<g id="south-%s">%s<rect class="dock-border" style="%s" x="%s" y="%s" width="%s" height="%s" /></g>' % ((n, plain, B) + tuple(f(v) for v in b))
s, k = re.subn(r'<rect id="south-(top|bottom|left|right)"[^>]*/>', edge, s); assert k == 4, k
def corner(m):
    n = m.group(1); (ax, ay, bx, by, cx, cy) = (float(v) for v in m.group(3, 4, 5, 6, 7, 8))
    def ring(r):
        # shrink the arc end points towards the centre to get the inner arc
        ix, iy = cx + (ax - cx) * r / R, cy + (ay - cy) * r / R
        jx, jy = cx + (bx - cx) * r / R, cy + (by - cy) * r / R
        return 'M %s,%s A %s %s 0 0 1 %s,%s L %s,%s A %s %s 0 0 0 %s,%s Z' % (f(ax), f(ay), f(R), f(R), f(bx), f(by), f(jx), f(jy), f(r), f(r), f(ix), f(iy))
    d = ring(R - 1)
    shade = '<path class="dock-border" style="opacity:%s;fill:#000000" d="%s" />' % (SHADE_OP, ring(R - SHADE_W)) if SHADE_W > 0 else ''
    # opacity at the arc's start (a) and end (b): ends touching the top or left edge are lit
    ends = {'topleft': (LIT, LIT), 'topright': (LIT, BACK), 'bottomright': (BACK, BACK), 'bottomleft': (BACK, LIT)}[n]
    g = '<linearGradient id="dockBorder-%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s"><stop offset="0" style="stop-color:#ffffff;stop-opacity:%s" /><stop offset="1" style="stop-color:#ffffff;stop-opacity:%s" /></linearGradient>' % (n, f(ax), f(ay), f(bx), f(by), ends[0], ends[1])
    return m.group(0) + shade + g + '<path class="dock-border" style="fill:url(#dockBorder-%s)" d="%s" />' % (n, d)
s, k = re.subn(r'<g id="south-(topleft|topright|bottomleft|bottomright)"><path style="([^"]*)" d="M ([\d.]+),([\d.]+) A [\d.]+ [\d.]+ 0 0 1 ([\d.]+),([\d.]+) L ([\d.]+),([\d.]+) Z" />', corner, s); assert k == 4, k
gzip.open(dst, 'wb').write(s.encode()); print('ok')
