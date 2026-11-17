// SPDX-License-Identifier: GPL-3.0-or-later
// The surface every control sits on: a piece of frosted glass.
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: tile
    property bool hovered: false
    readonly property color ink: Kirigami.Theme.textColor
    // light glass (dark text) takes stronger highlights than dark glass
    readonly property real k: ink.hslLightness > 0.5 ? 1.0 : 2.2
    radius: Math.min(Kirigami.Units.gridUnit * 1.5, height / 2)

    // In a window without a background of its own (the Control Center's floating mode) every tile asks for
    // blur behind its own outline and so becomes a piece of glass by itself.
    readonly property bool glass: Window.window ? Window.window.glassTiles === true : false
    Loader {
        anchors.fill: parent
        source: tile.glass ? "TileGlass.qml" : ""
        onLoaded: item.radius = Qt.binding(() => tile.radius)
    }

    // Floating over the desktop there is no panel to keep the text readable, so the glass carries a shade of
    // its own: with light text a dark one, which turns a white window behind the tile into a mid grey.
    Rectangle {
        visible: tile.glass
        anchors.fill: parent
        radius: tile.radius
        readonly property bool lightText: tile.ink.hslLightness > 0.5
        // light glass is a pale grey rather than white, and has a hairline, so a tile still reads as a surface
        // when the window behind it is white
        color: lightText ? Qt.rgba(0, 0, 0, 0.34) : Qt.rgba(0.86, 0.87, 0.90, 0.62)
        border.width: lightText ? 0 : 1
        border.color: Qt.rgba(0, 0, 0, 0.16)
    }

    // The glass look, drawn here because the compositor only blurs behind the tile: a sheen that is a little
    // lighter towards the top, a rim that catches the light at the top left and again faintly at the bottom
    // right, and a soft glow just inside the edge.
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, tile.hovered ? 0.14 * tile.k : 0.09 * tile.k) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, tile.hovered ? 0.07 * tile.k : 0.025 * tile.k) }
    }
    Canvas {
        id: rim
        anchors.fill: parent
        readonly property real r: Math.max(0, Math.min(tile.radius, width / 2, height / 2))
        readonly property color ink: tile.ink
        onRChanged: requestPaint()
        onInkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width < 2 || height < 2) {
                return;
            }
            const c = (a) => Qt.rgba(1, 1, 1, Math.min(1, a * tile.k));
            // glow just inside the edge: wide strokes of the outline, clipped to the shape
            ctx.save();
            ctx.beginPath();
            ctx.roundedRect(0, 0, width, height, r, r);
            ctx.clip();
            for (const [w, a] of [[16, 0.018], [9, 0.024], [4, 0.030]]) {
                ctx.beginPath();
                ctx.roundedRect(0, 0, width, height, r, r);
                ctx.lineWidth = w;
                ctx.strokeStyle = c(a);
                ctx.stroke();
            }
            ctx.restore();
            // the rim itself
            const light = ctx.createLinearGradient(0, 0, width, height);
            light.addColorStop(0.0, c(0.46));
            light.addColorStop(0.30, c(0.15));
            light.addColorStop(0.70, c(0.06));
            light.addColorStop(1.0, c(0.24));
            ctx.beginPath();
            ctx.roundedRect(0.6, 0.6, width - 1.2, height - 1.2, Math.max(0, r - 0.6), Math.max(0, r - 0.6));
            ctx.lineWidth = 1.0;
            ctx.strokeStyle = light;
            ctx.stroke();
        }
    }
}
