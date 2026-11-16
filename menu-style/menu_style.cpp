// SPDX-License-Identifier: GPL-3.0-only
// Qt widget style "LiquidGlass": Kvantum for everything, except that the menu panel is drawn here.
//
// Kvantum limits what a theme can do with menus: the blur shape is capped at a 10px corner, the frame art is
// stretched, and its translucency fade is square-cornered. Drawing the panel ourselves and handing KWin a blur
// shape cut from the same outline removes all three.
//
// Adapted from the menu style of macos-tahoe-liquid-kde,
// Copyright (C) 2026 Lester Cordero Murillo, https://github.com/lestercorderomurillo/macos-tahoe-liquid-kde
// Changes for plasma-liquid-glass: circular corners of a configurable radius (so the compositor's rounded cut
// can follow them), fainter shadow, no dark outline, any Kvantum theme listed in LIQUIDGLASS_MENU_THEMES,
// one-colour menu icons redrawn in the menu text colour when they would be dark on dark (or light on light).
#include <QApplication>
#include <QFile>
#include <QHash>
#include <QMenu>
#include <QPainter>
#include <QPainterPath>
#include <QProxyStyle>
#include <QSettings>
#include <QStandardPaths>
#include <QStyleFactory>
#include <QStyleOption>
#include <QStylePlugin>
#include <QWindow>
#include <KWindowEffects>

namespace {
int envInt(const char *name, int fallback)
{
    bool ok = false;
    const int value = qEnvironmentVariableIntValue(name, &ok);
    return ok ? value : fallback;
}
// corner radius of the menu in px; keep MenuCornerRadius of the glass effect at the same value
const int kRadius = envInt("LIQUIDGLASS_MENU_RADIUS", 16);
// space Kvantum's menu frame leaves around the items; whatever its margin has beyond this becomes shadow room
const int kFrame = 9;
// distance from the menu edge to the items
const int kInset = envInt("LIQUIDGLASS_MENU_INSET", 5);
// strength of the drop shadow, alpha (0-255) added per pixel ring
const int kShadowAlpha = envInt("LIQUIDGLASS_MENU_SHADOW", 4);
// light line just inside the edge, alpha (0-255)
const int kLineAlpha = envInt("LIQUIDGLASS_MENU_LINE", 56);

QPainterPath contour(const QRectF &rect, qreal radius)
{
    const qreal r = qMax(qreal(0), qMin(radius, qMin(rect.width(), rect.height()) / 2));
    QPainterPath path;
    path.addRoundedRect(rect, r, r);
    return path;
}

// Kvantum's theme name ("WhiteSur", "WhiteSurDark"...) from the user's Kvantum config.
QString kvantumTheme()
{
    const auto config = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    return QSettings(config + "/Kvantum/kvantum.kvconfig", QSettings::IniFormat).value("theme").toString();
}

// The colour Kvantum draws menu item text in: text.normal.color of [MenuItem] in the theme's .kvconfig.
// A theme "FooDark" lives in the directory of "Foo". Invalid when it cannot be found.
QColor menuTextColor(const QString &theme)
{
    static QHash<QString, QColor> cache;
    const auto known = cache.constFind(theme);
    if (known != cache.constEnd()) return *known;
    QColor color;
    QStringList dirs{theme};
    if (theme.endsWith("Dark")) dirs << theme.chopped(4);
    QStringList roots{QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/Kvantum"};
    for (const QString &data : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation)) roots << data + "/Kvantum";
    for (const QString &root : std::as_const(roots)) {
        for (const QString &dir : std::as_const(dirs)) {
            const QString path = root + '/' + dir + '/' + theme + ".kvconfig";
            if (!QFile::exists(path)) continue;
            QSettings settings(path, QSettings::IniFormat);
            color = QColor(settings.value("MenuItem/text.normal.color").toString());
            if (color.isValid()) break;
        }
        if (color.isValid()) break;
    }
    cache.insert(theme, color);
    return color;
}

int luma(const QColor &c) { return (c.red() * 299 + c.green() * 587 + c.blue() * 114) / 1000; }

// A one-colour icon that would be hard to see next to the menu text - a dark outline icon of a light icon theme
// on a dark glass menu, or the reverse - redrawn in the text colour. Colourful icons are returned unchanged.
QIcon readableIcon(const QIcon &icon, const QSize &size, qreal ratio, const QColor &text)
{
    static QHash<quint64, QIcon> cache;
    const quint64 key = quint64(icon.cacheKey()) ^ (quint64(text.rgba()) << 32) ^ quint64(size.width() * 131 + int(ratio * 16));
    const auto known = cache.constFind(key);
    if (known != cache.constEnd()) return *known;
    QImage image = icon.pixmap(size, ratio).toImage().convertToFormat(QImage::Format_ARGB32);
    qint64 sum = 0, count = 0;
    bool plain = !image.isNull();
    for (int y = 0; plain && y < image.height(); ++y) {
        const QRgb *row = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            if (qAlpha(row[x]) < 48) continue;
            const int hi = qMax(qRed(row[x]), qMax(qGreen(row[x]), qBlue(row[x])));
            const int lo = qMin(qRed(row[x]), qMin(qGreen(row[x]), qBlue(row[x])));
            if (hi - lo > 36) { plain = false; break; }
            sum += (qRed(row[x]) * 299 + qGreen(row[x]) * 587 + qBlue(row[x]) * 114) / 1000;
            ++count;
        }
    }
    QIcon result = icon;
    if (plain && count > 0 && qAbs(int(sum / count) - luma(text)) > 110) {
        QPainter tint(&image);
        tint.setCompositionMode(QPainter::CompositionMode_SourceIn);
        tint.fillRect(image.rect(), text);
        tint.end();
        QPixmap pixmap = QPixmap::fromImage(image);
        pixmap.setDevicePixelRatio(ratio);
        result = QIcon(pixmap);
    }
    if (cache.size() > 512) cache.clear();
    cache.insert(key, result);
    return result;
}

class MenuStyle final : public QProxyStyle {
public:
    explicit MenuStyle(QStyle *base) : QProxyStyle(base) {}
    bool themed(const QWidget *widget) const {
        if (!qobject_cast<const QMenu *>(widget) || widget->testAttribute(Qt::WA_StyleSheetTarget)) return false;
        const QString theme = kvantumTheme();
        const QString wanted = qEnvironmentVariable("LIQUIDGLASS_MENU_THEMES", QStringLiteral("WhiteSur"));
        for (const QString &prefix : wanted.split(',', Qt::SkipEmptyParts))
            if (theme.startsWith(prefix.trimmed())) return true;
        return false;
    }
    void drawControl(ControlElement element, const QStyleOption *option,
                     QPainter *painter, const QWidget *widget) const override {
        if (element == CE_MenuItem && themed(widget)) {
            const auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
            const QColor text = menuTextColor(kvantumTheme());
            if (item && !item->icon.isNull() && text.isValid()) {
                QStyleOptionMenuItem copy(*item);
                const int extent = baseStyle()->pixelMetric(PM_SmallIconSize, option, widget);
                copy.icon = readableIcon(item->icon, QSize(extent, extent), widget ? widget->devicePixelRatioF() : qApp->devicePixelRatio(), text);
                QProxyStyle::drawControl(element, &copy, painter, widget);
                return;
            }
        }
        QProxyStyle::drawControl(element, option, painter, widget);
    }
    int pixelMetric(PixelMetric metric, const QStyleOption *option, const QWidget *widget) const override {
        const int value = QProxyStyle::pixelMetric(metric, option, widget);
        if (themed(widget) && (metric == PM_MenuHMargin || metric == PM_MenuVMargin))
            return qMax(0, value - (kFrame - kInset));
        return value;
    }
    void drawPrimitive(PrimitiveElement element, const QStyleOption *option,
                       QPainter *painter, const QWidget *widget) const override {
        if (element != PE_PanelMenu || !themed(widget)) {
            QProxyStyle::drawPrimitive(element, option, painter, widget);
            return;
        }
        // Let Kvantum resolve the actual body colour (theme, light/dark, opacity) and sample its interior.
        QImage sample(1, 1, QImage::Format_ARGB32_Premultiplied);
        sample.fill(Qt::transparent);
        {
            QPainter probe(&sample);
            probe.translate(-option->rect.center());
            baseStyle()->drawPrimitive(element, option, &probe, widget);
        }
        const bool translucent = widget->testAttribute(Qt::WA_TranslucentBackground);
        const int margin = baseStyle()->pixelMetric(PM_MenuHMargin, option, widget);
        const qreal shadow = translucent ? qMax(0, margin - kFrame) : 0;
        const QRectF surface = QRectF(option->rect).adjusted(shadow, shadow, -shadow, -shadow);
        const QPainterPath shape = contour(surface, kRadius);
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        painter->setCompositionMode(QPainter::CompositionMode_Source);
        painter->fillRect(option->rect, Qt::transparent);
        painter->setCompositionMode(QPainter::CompositionMode_SourceOver);
        if (shadow > 0 && kShadowAlpha > 0) {
            for (int i = int(shadow); i > 0; --i) {
                const auto outer = contour(surface.adjusted(-i, -i, i, i), kRadius + i);
                painter->fillPath(outer.subtracted(shape), QColor(0, 0, 0, kShadowAlpha));
            }
        }
        painter->fillPath(shape, sample.pixelColor(0, 0));
        if (kLineAlpha > 0) {
            const auto inner = contour(surface.adjusted(1, 1, -1, -1), kRadius - 1);
            painter->fillPath(shape.subtracted(inner), QColor(255, 255, 255, kLineAlpha));
        }
        painter->restore();
        if (translucent && widget->windowHandle()) {
            // Rasterise the outline and take every pixel it covers by half or more. A polygon of the path
            // lands a pixel or two inside the arc and leaves an unblurred gap under the edge line.
            QImage mask(option->rect.size(), QImage::Format_ARGB32_Premultiplied);
            mask.fill(Qt::transparent);
            {
                QPainter cover(&mask);
                cover.setRenderHint(QPainter::Antialiasing);
                cover.translate(-option->rect.topLeft());
                cover.fillPath(shape, Qt::black);
            }
            QRegion region;
            for (int y = 0; y < mask.height(); ++y) {
                const QRgb *row = reinterpret_cast<const QRgb *>(mask.constScanLine(y));
                int left = 0, right = mask.width() - 1;
                while (left <= right && qAlpha(row[left]) < 128) ++left;
                while (right >= left && qAlpha(row[right]) < 128) --right;
                if (left <= right) region += QRect(option->rect.x() + left, option->rect.y() + y, right - left + 1, 1);
            }
            KWindowEffects::enableBlurBehind(widget->windowHandle(), true, region);
        }
    }
};
}

class MenuStylePlugin final : public QStylePlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QStyleFactoryInterface" FILE "menu_style.json")
public:
    QStyle *create(const QString &key) override {
        if (key.compare("LiquidGlass", Qt::CaseInsensitive) != 0) return nullptr;
        auto *base = QStyleFactory::create("kvantum");
        return base ? new MenuStyle(base) : nullptr;
    }
};
#include "menu_style.moc"
