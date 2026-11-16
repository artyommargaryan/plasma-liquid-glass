// SPDX-License-Identifier: GPL-3.0-or-later
// A thin line slider with an icon in front: click or drag anywhere along it, or turn the wheel over it.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: bar
    property real from: 0
    property real to: 1
    property real value: 0
    property string iconName
    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property color ink: Kirigami.Theme.textColor
    signal moved(real value)

    implicitHeight: Kirigami.Units.gridUnit * 1.5
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.Slider

    Kirigami.Icon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        width: Kirigami.Units.iconSizes.small
        height: width
        source: bar.iconName
        isMask: true
        color: bar.ink
    }

    Item {
        id: track
        anchors {
            left: icon.right
            right: parent.right
            leftMargin: Kirigami.Units.smallSpacing * 2
            verticalCenter: parent.verticalCenter
        }
        height: 5

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(bar.ink.r, bar.ink.g, bar.ink.b, 0.25)
        }
        Rectangle {
            height: parent.height
            width: Math.max(height, parent.width * bar.ratio)
            radius: height / 2
            color: Qt.rgba(bar.ink.r, bar.ink.g, bar.ink.b, 0.92)
        }
    }

    MouseArea {
        anchors.fill: parent
        function set(x: real) {
            const r = Math.max(0, Math.min(1, (x - track.x) / Math.max(1, track.width)));
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
