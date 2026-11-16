// SPDX-License-Identifier: GPL-3.0-or-later
// A control that is switched on and off: a knob, and when there is room a title with a status line.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore

Tile {
    id: tile
    property string iconName
    property string title
    property string status
    property bool on: false
    // a narrow tile shows the knob alone, the title moves to the tooltip
    readonly property bool compact: width < Kirigami.Units.gridUnit * 7
    signal clicked()

    hovered: area.containsMouse
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: status

    Knob {
        id: knob
        anchors.verticalCenter: parent.verticalCenter
        x: tile.compact ? (parent.width - width) / 2 : Kirigami.Units.largeSpacing
        iconName: tile.iconName
        on: tile.on
        pressed: area.pressed
    }

    Column {
        visible: !tile.compact
        anchors {
            left: knob.right
            right: parent.right
            leftMargin: Kirigami.Units.largeSpacing
            rightMargin: Kirigami.Units.largeSpacing
            verticalCenter: parent.verticalCenter
        }
        PlasmaComponents.Label {
            width: parent.width
            text: tile.title
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
        PlasmaComponents.Label {
            width: parent.width
            visible: text.length > 0
            text: tile.status
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        active: tile.compact
        mainText: tile.title
        subText: tile.status
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.clicked()
        }
    }
}
