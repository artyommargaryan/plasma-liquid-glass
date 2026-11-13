# Rebuilds the four shadow corner tiles of widgets/panel-background for corners of radius R, so the shadow hugs
# the rounded dock instead of leaving an unshadowed (light) gap next to each corner.
# usage: panel_shadow.py R in.svgz out.svgz
import sys, os, re, gzip
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtGui import QGuiApplication, QImage, QPainter
from PySide6.QtCore import QRectF, QByteArray, Qt
R = float(sys.argv[1]); src, dst = sys.argv[2], sys.argv[3]; M = 12.0; S = M + R
s = gzip.open(src).read().decode()
app = QGuiApplication(sys.argv); r = QSvgRenderer(QByteArray(s.encode()))
# alpha of the straight top shadow, per pixel of distance from the panel edge (x8 oversampled)
K = 8; img = QImage(12, 24 * K, QImage.Format_ARGB32); img.fill(Qt.transparent)
p = QPainter(img); r.render(p, 'shadow-top', QRectF(0, 0, 12, 24 * K)); p.end()
alpha = [img.pixelColor(6, y).alphaF() for y in range(24 * K)]
prof = lambda d: alpha[min(max(int(round((M - d) * K)), 0), 24 * K - 1)]   # d = px outside the edge
print('profile', ['%.3f' % prof(d) for d in range(0, 13)], 'under panel', '%.3f' % max(alpha[int(M * K) + 2:]))
f = lambda v: ('%.4f' % v).rstrip('0').rstrip('.')
def elem_span(s, i):
    m = re.search(r'<(\w+)\b[^>]*\bid="%s"[^>]*?(/>|>)' % re.escape(i), s, re.S)
    if m.group(2) == '/>': return m.start(), m.end()
    e = s.index('</%s>' % m.group(1), m.start()); return m.start(), e + len(m.group(1)) + 3
names = ['topleft', 'topright', 'bottomright', 'bottomleft']; defs = []; repl = {}
X0, Y0 = 300.0, 100.0   # free area of the canvas; FrameSvg only uses each tile's size
for q, n in enumerate(names):
    sx, sy = (-1 if q in (0, 3) else 1), (-1 if q in (0, 1) else 1)
    cx, cy = X0 + q * 100, Y0                       # centre of the corner circle = inner corner of the tile
    ox, oy = cx + sx * S, cy + sy * S
    x, y = min(cx, ox), min(cy, oy)
    stops = ''.join('<stop offset="%s" style="stop-color:#000000;stop-opacity:%s" />' % (f((R + d / 2) / S), f(prof(d / 2))) for d in range(0, 25))
    defs.append('<radialGradient id="dockShadowGrad%d" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" fx="%s" fy="%s" r="%s"><stop offset="0" style="stop-color:#000000;stop-opacity:0" /><stop offset="%s" style="stop-color:#000000;stop-opacity:0" />%s</radialGradient>' % (q, f(cx), f(cy), f(cx), f(cy), f(S), f((R - 0.01) / S), stops))
    repl['shadow-' + n] = '<g id="shadow-%s"><rect style="fill:url(#dockShadowGrad%d)" x="%s" y="%s" width="%s" height="%s" /></g>' % (n, q, f(x), f(y), f(S), f(S))
for k in ('shadow-topright', 'shadow-bottomright', 'shadow-bottomleft', 'shadow-topleft'):   # <use> refs first
    st, en = elem_span(s, k); s = s[:st] + repl[k] + s[en:]
s = re.sub(r'<radialGradient id="dockShadowGrad\d".*?</radialGradient>', '', s, flags=re.S)
i = s.index('</defs>'); s = s[:i] + ''.join(defs) + s[i:]
gzip.open(dst, 'wb').write(s.encode()); print('ok')
