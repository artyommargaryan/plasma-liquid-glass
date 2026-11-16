// SPDX-License-Identifier: GPL-3.0-or-later
// A round icon. While its control is on it is a solid light disc with the icon in the accent colour;
// while off, just the icon on a faint disc.
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: knob
    property string iconName
    property bool on: false
    property bool pressed: false
    readonly property color ink: Kirigami.Theme.textColor
    width: Kirigami.Units.gridUnit * 2.4
    height: width
    radius: width / 2
    color: on ? Qt.rgba(ink.r, ink.g, ink.b, 0.96) : Qt.rgba(ink.r, ink.g, ink.b, 0.0)
    scale: pressed ? 0.93 : 1
    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.smallMedium
        height: width
        source: knob.iconName
        isMask: true
        color: knob.on ? Kirigami.Theme.highlightColor : knob.ink
    }
}
