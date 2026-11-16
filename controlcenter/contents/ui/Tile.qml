// SPDX-License-Identifier: GPL-3.0-or-later
// The translucent rounded surface every control sits on.
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    property bool hovered: false
    radius: Math.min(Kirigami.Units.gridUnit * 1.4, height / 2)
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, hovered ? 0.13 : 0.08)
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
}
