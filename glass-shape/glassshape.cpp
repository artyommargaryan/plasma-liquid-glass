// SPDX-License-Identifier: GPL-3.0-or-later
#include "glassshape.h"
#include <KWindowEffects>
#include <QHash>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QPointer>
#include <QQuickWindow>
#include <QSet>
#include <QTimer>

namespace {
// The shapes of one window; rebuilds the blur region once per event-loop turn however many of them changed.
class Registry : public QObject
{
public:
    explicit Registry(QQuickWindow *window) : QObject(window), m_window(window)
    {
        m_timer.setSingleShot(true);
        m_timer.setInterval(0);
        connect(&m_timer, &QTimer::timeout, this, &Registry::apply);
        // positions of the shapes can change without any of them being told (an ancestor moved)
        connect(window, &QQuickWindow::afterAnimating, this, [this] { if (m_dirtyOnFrame) { m_dirtyOnFrame = false; m_timer.start(); } });
        connect(window, &QQuickWindow::widthChanged, this, [this] { schedule(); });
        connect(window, &QQuickWindow::heightChanged, this, [this] { schedule(); });
        // Every time the window is shown it gets a new surface, which knows nothing of the region set on the
        // previous one: forget what was sent, and send it again once the new surface has drawn a frame.
        // The owner of the window may reset its blur whenever it is shown: a Plasma dialog without a background
        // switches blur off as part of showing itself, after our region went out. So on every show the region
        // is sent again, now and a few more times while the window settles.
        connect(window, &QQuickWindow::visibleChanged, this, [this] { resend(); });
        // the window may already be on screen when its first shape registers
        resend();
    }
    void add(GlassShape *shape) { m_shapes.insert(shape); schedule(); }
    void remove(GlassShape *shape) { m_shapes.remove(shape); schedule(); }
    void schedule() { m_dirtyOnFrame = true; m_timer.start(); if (m_window) m_window->update(); }

private:
    void resend()
    {
        if (!m_window || !m_window->isVisible()) return;
        // a Plasma dialog was seen to switch blur off as late as 0.7s after it appeared
        for (int delay : {0, 60, 200, 500, 900, 1500}) {
            QTimer::singleShot(delay, this, [this] { m_sent = false; apply(); });
        }
    }
    void apply()
    {
        if (!m_window || !m_window->isVisible()) return;
        const QSize size = m_window->size();
        if (size.isEmpty()) return;
        // Paint every outline into a mask and take the pixels covered by half or more: exact for round shapes,
        // where a polygon of the outline would land a pixel inside the curve.
        QImage mask(size, QImage::Format_ARGB32_Premultiplied);
        mask.fill(Qt::transparent);
        {
            QPainter painter(&mask);
            painter.setRenderHint(QPainter::Antialiasing);
            for (GlassShape *shape : std::as_const(m_shapes)) {
                if (!shape->isVisible() || shape->window() != m_window) continue;
                // an item is only on screen if all its ancestors are visible, which isVisible() already covers
                const QRectF rect = shape->mapRectToScene(QRectF(0, 0, shape->width(), shape->height()));
                if (rect.isEmpty()) continue;
                const qreal r = qMin(shape->radius(), qMin(rect.width(), rect.height()) / 2);
                QPainterPath path;
                path.addRoundedRect(rect, r, r);
                painter.fillPath(path, Qt::black);
            }
        }
        QRegion region;
        for (int y = 0; y < mask.height(); ++y) {
            const QRgb *row = reinterpret_cast<const QRgb *>(mask.constScanLine(y));
            int x = 0;
            while (x < mask.width()) {
                while (x < mask.width() && qAlpha(row[x]) < 128) ++x;
                const int start = x;
                while (x < mask.width() && qAlpha(row[x]) >= 128) ++x;
                if (x > start) region += QRect(start, y, x - start, 1);
            }
        }
        if (m_sent && region == m_last) return;
        m_last = region;
        m_sent = true;
        KWindowEffects::enableBlurBehind(m_window, !region.isEmpty(), region);
        // A blur region only takes effect with the next frame the window commits, and a window whose content
        // is not changing commits none: draw one now, and one more shortly after for a region sent mid-frame.
        m_window->update();
        QTimer::singleShot(80, this, [this] { if (m_window) m_window->update(); });
    }
    QPointer<QQuickWindow> m_window;
    QSet<GlassShape *> m_shapes;
    QTimer m_timer;
    QRegion m_last;
    bool m_dirtyOnFrame = false;
    bool m_sent = false;
};

QHash<QQuickWindow *, Registry *> &registries()
{
    static QHash<QQuickWindow *, Registry *> map;
    return map;
}

Registry *registryFor(QQuickWindow *window)
{
    Registry *&registry = registries()[window];
    if (!registry) {
        registry = new Registry(window);
        QObject::connect(window, &QObject::destroyed, [window] { registries().remove(window); });
    }
    return registry;
}
}

GlassShape::GlassShape(QQuickItem *parent) : QQuickItem(parent) {}

GlassShape::~GlassShape()
{
    if (m_window && registries().contains(m_window)) registries().value(m_window)->remove(this);
}

void GlassShape::setRadius(qreal radius)
{
    if (qFuzzyCompare(radius, m_radius)) return;
    m_radius = radius;
    Q_EMIT radiusChanged();
    changed();
}

void GlassShape::attach(QQuickWindow *window)
{
    if (window == m_window) return;
    if (m_window && registries().contains(m_window)) registries().value(m_window)->remove(this);
    m_window = window;
    if (m_window) registryFor(m_window)->add(this);
}

void GlassShape::changed()
{
    if (m_window && registries().contains(m_window)) registries().value(m_window)->schedule();
}

void GlassShape::itemChange(ItemChange change, const ItemChangeData &data)
{
    QQuickItem::itemChange(change, data);
    if (change == ItemSceneChange) attach(data.window);
    else if (change == ItemVisibleHasChanged) changed();
}

void GlassShape::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    changed();
}
