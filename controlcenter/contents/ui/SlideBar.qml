// SPDX-License-Identifier: GPL-3.0-or-later
// A thick pill slider: click or drag anywhere on it, or turn the wheel over it.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: bar
    property real from: 0
    property real to: 1
    property real value: 0
    property string iconName
    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    signal moved(real value)

    implicitHeight: Kirigami.Units.gridUnit * 1.5
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.Slider

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14)
        clip: true

        Rectangle {
            height: parent.height
            // never narrower than the round end, so a low value still reads as a filled cap
            width: Math.max(parent.height, parent.width * bar.ratio)
            radius: height / 2
            color: Kirigami.Theme.textColor
            opacity: 0.85
        }
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            x: (parent.height - width) / 2
            width: Kirigami.Units.iconSizes.small
            height: width
            source: bar.iconName
            isMask: true
            // dark on a light fill and light on a dark one; a theme's background colour is not always the opposite
            // of its text colour (light themes with dark glass popups draw light text)
            color: Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1e1e1e" : "#f2f2f2"
        }
    }

    MouseArea {
        anchors.fill: parent
        function set(x: real) {
            const r = Math.max(0, Math.min(1, (x - height / 2) / Math.max(1, width - height)));
            bar.moved(bar.from + r * (bar.to - bar.from));
        }
        onPressed: mouse => set(mouse.x)
        onPositionChanged: mouse => { if (pressed) set(mouse.x); }
        onWheel: wheel => {
            const step = (bar.to - bar.from) * 0.05 * (wheel.angleDelta.y > 0 ? 1 : -1);
            bar.moved(Math.max(bar.from, Math.min(bar.to, bar.value + step)));
        }
    }
}
