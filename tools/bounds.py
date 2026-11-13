import sys, os, re
os.environ['QT_QPA_PLATFORM']='offscreen'
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtGui import QGuiApplication
app=QGuiApplication(sys.argv); r=QSvgRenderer(sys.argv[1]); print('valid', r.isValid())
ids=re.findall(r'id="([a-z-]+)"', open(sys.argv[1]).read())
for i in ids:
    if any(i==p+n for p in ('','mask-','shadow-') for n in ('topleft','top','topright','left','center','right','bottomleft','bottom','bottomright')) or 'hint' in i:
        b=r.transformForElement(i).mapRect(r.boundsOnElement(i)); print('%-28s %8.2f %8.2f %7.2f x %6.2f' % (i, b.x(), b.y(), b.width(), b.height()))
