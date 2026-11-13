import re, sys, gzip
R = float(sys.argv[1]); src, dst = sys.argv[2], sys.argv[3]
MASK_INSET = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0   # how far the blur stays inside the corner curve
s = open(src).read()
def elem_span(s, i):
    m = re.search(r'<(\w+)\b[^>]*\bid="%s"[^>]*?(/>|>)' % re.escape(i), s, re.S)
    if not m: raise SystemExit("missing id " + i)
    if m.group(2) == '/>': return m.start(), m.end()
    e = s.index('</%s>' % m.group(1), m.start())
    return m.start(), e + len(m.group(1)) + 3
m = re.search(r'opacity:([0-9.]+);fill:#000000"\s+id="south-center"', s) or re.search(r'id="south-center"', s)
st, en = elem_span(s, 'south-center'); fill_style = re.search(r'style="([^"]*)"', s[st:en]).group(1)
def pieces(prefix, x0, y0, style):
    # 3x3 grid around a 12x12 centre at (x0, y0); corners are exact quarter circles of radius R
    C = 12.0; x1, y1 = x0 + C, y0 + C
    f = lambda v: ('%.4f' % v).rstrip('0').rstrip('.')
    P = lambda d, i: '<path id="%s%s" style="%s" d="%s" />' % (prefix, i, style, d)
    Rc = lambda x, y, w, h, i: '<rect id="%s%s" style="%s" x="%s" y="%s" width="%s" height="%s" />' % (prefix, i, style, f(x), f(y), f(w), f(h))
    # the blur mask's corners are slightly smaller than the fill's, so no blurred pixel pokes out past the curve
    r = R - MASK_INSET if 'mask' in prefix else R
    a = 'A %s %s 0 0 1' % (f(r), f(r))
    def corner(d, i, bx, by):
        return '<g id="%s%s"><path style="%s" d="%s" /><rect style="fill:none" x="%s" y="%s" width="%s" height="%s" /></g>' % (prefix, i, style, d, f(bx), f(by), f(R), f(R))
    return {
        'topleft': corner('M %s,%s %s %s,%s L %s,%s Z' % (f(x0-r), f(y0), a, f(x0), f(y0-r), f(x0), f(y0)), 'topleft', x0-R, y0-R),
        'topright': corner('M %s,%s %s %s,%s L %s,%s Z' % (f(x1), f(y0-r), a, f(x1+r), f(y0), f(x1), f(y0)), 'topright', x1, y0-R),
        'bottomright': corner('M %s,%s %s %s,%s L %s,%s Z' % (f(x1+r), f(y1), a, f(x1), f(y1+r), f(x1), f(y1)), 'bottomright', x1, y1),
        'bottomleft': corner('M %s,%s %s %s,%s L %s,%s Z' % (f(x0), f(y1+r), a, f(x0-r), f(y1), f(x0), f(y1)), 'bottomleft', x0-R, y1),
        'top': Rc(x0, y0-R, C, R, 'top'), 'bottom': Rc(x0, y1, C, R, 'bottom'),
        'left': Rc(x0-R, y0, R, C, 'left'), 'right': Rc(x1, y0, R, C, 'right'),
        'center': Rc(x0, y0, C, C, 'center'),
    }
for prefix, x0, y0, style in (('south-', 44.0, 1004.3622, fill_style), ('south-mask-', 128.0, 1002.3622, 'fill:#000000')):
    for name, xml in pieces(prefix, x0, y0, style).items():
        st, en = elem_span(s, prefix + name)
        s = s[:st] + xml + s[en:]
# Plasma looks the blur mask up as "mask-" + prefix + piece, i.e. mask-south-topleft
s = s.replace('id="south-mask-', 'id="mask-south-')
gzip.open(dst, 'wb').write(s.encode())
print("ok R=%g fill=%s" % (R, fill_style))
