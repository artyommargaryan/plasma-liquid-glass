// SPDX-License-Identifier: GPL-3.0-or-later
// A round icon that is filled with the accent colour while its control is on.
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: knob
    property string iconName
    property bool on: false
    property bool pressed: false
    width: Kirigami.Units.gridUnit * 2.6
    height: width
    radius: width / 2
    color: on ? Kirigami.Theme.highlightColor
              : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
    scale: pressed ? 0.93 : 1
    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.smallMedium
        height: width
        source: knob.iconName
        isMask: true
        color: knob.on ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
    }
}
