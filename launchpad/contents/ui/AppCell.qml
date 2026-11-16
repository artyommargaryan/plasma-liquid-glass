// SPDX-License-Identifier: GPL-3.0-or-later
// One app: icon with its name underneath.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: cell

    required property int index
    required property var model
    property bool current: false
    property int iconSize: Kirigami.Units.iconSizes.huge

    signal activated()
    signal menuRequested()
    signal hovered()

    Rectangle {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing / 2
        radius: Kirigami.Units.gridUnit * 0.8
        color: Kirigami.Theme.textColor
        opacity: cell.current ? 0.14 : 0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
    }

    Kirigami.Icon {
        id: icon
        anchors.horizontalCenter: parent.horizontalCenter
        y: Kirigami.Units.smallSpacing * 2
        width: cell.iconSize
        height: cell.iconSize
        source: cell.model.decoration
        scale: area.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
    }

    PlasmaComponents.Label {
        anchors {
            top: icon.bottom
            topMargin: Kirigami.Units.smallSpacing
            left: parent.left
            right: parent.right
            leftMargin: Kirigami.Units.smallSpacing
            rightMargin: Kirigami.Units.smallSpacing
        }
        text: cell.model.display ?? ""
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
        textFormat: Text.PlainText
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: cell.hovered()
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                cell.menuRequested();
            } else {
                cell.activated();
            }
        }
    }
}
