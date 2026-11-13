# Adjusts a Kvantum .kvconfig for the glass menu frame made by kv_menu.py.
# usage: kv_config.py in.kvconfig out.kvconfig [--light-text]
#   [Menu] frame.top/bottom/left/right=15, menu_blur_radius=10, reduce_menu_opacity=0
#   --light-text: light menu text (for a light theme whose menus sit on dark glass)
import re, sys
src, dst = sys.argv[1], sys.argv[2]; light = '--light-text' in sys.argv[3:]
s = open(src).read()
def section(name, fn):
    global s
    m = re.search(r'(?m)^\[%s\]\n(.*?)(?=^\[|\Z)' % re.escape(name), s, re.S)
    if not m: raise SystemExit('no [%s] section in %s' % (name, src))
    s = s[:m.start(1)] + fn(m.group(1)) + s[m.end(1):]
def setkey(body, key, val):
    line = '%s=%s' % (key, val)
    if re.search(r'(?m)^%s=' % re.escape(key), body): return re.sub(r'(?m)^%s=.*$' % re.escape(key), line, body)
    tail = re.search(r'\n*\Z', body).group(0)
    return body[:len(body) - len(tail)] + '\n' + line + (tail or '\n')
def menu(body):
    for side in ('top', 'bottom', 'left', 'right'): body = setkey(body, 'frame.' + side, '15')
    return text(body)
def text(body):
    if light:
        body = setkey(body, 'text.normal.color', '#dfdfdf'); body = setkey(body, 'text.normal.inactive.color', '#dfdfdf')
    return body
def general(body):
    return setkey(setkey(body, 'menu_blur_radius', '10'), 'reduce_menu_opacity', '0')
section('Menu', menu); section('MenuItem', text); section('%General', general)
open(dst, 'w').write(s)
