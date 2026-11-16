// SPDX-License-Identifier: GPL-3.0-or-later
// GlassShape: put one inside a rounded surface of a window that has no background of its own. All shapes of a
// window together are handed to the compositor as that window's blur region, so each surface becomes a piece of
// glass of its own instead of the window being one blurred rectangle.
#pragma once
#include <QQuickItem>
#include <qqmlregistration.h>

class GlassShape : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
public:
    explicit GlassShape(QQuickItem *parent = nullptr);
    ~GlassShape() override;
    qreal radius() const { return m_radius; }
    void setRadius(qreal radius);
Q_SIGNALS:
    void radiusChanged();
protected:
    void itemChange(ItemChange change, const ItemChangeData &data) override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
private:
    void attach(QQuickWindow *window);
    void changed();
    qreal m_radius = 0;
    QQuickWindow *m_window = nullptr;
};
