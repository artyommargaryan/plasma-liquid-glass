// SPDX-License-Identifier: GPL-3.0-or-later
// A small text button.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: pill
    property alias text: label.text
    signal clicked()
    implicitWidth: label.implicitWidth + Kirigami.Units.gridUnit * 1.2
    implicitHeight: label.implicitHeight + Kirigami.Units.smallSpacing * 2
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    opacity: enabled ? 1 : 0.4
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                   area.pressed ? 0.22 : (area.containsMouse ? 0.16 : 0.10))
    Accessible.role: Accessible.Button
    Accessible.name: text

    PlasmaComponents.Label {
        id: label
        anchors.centerIn: parent
        textFormat: Text.PlainText
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: pill.clicked()
    }
}
