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
    // With splitKnob the round knob is a button of its own (knobClicked), and clicked() is for the rest of the tile:
    // the knob switches, the tile opens the details.
    property bool splitKnob: false
    signal clicked()
    signal knobClicked()

    hovered: area.containsMouse
    // one-row tiles are pills, the square ones circles
    radius: height / 2
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
        pressed: tile.splitKnob ? knobArea.pressed : area.pressed
        z: 1
        MouseArea {
            id: knobArea
            anchors.fill: parent
            enabled: tile.splitKnob
            visible: tile.splitKnob
            onClicked: tile.knobClicked()
        }
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
        z: 0
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.clicked()
        }
    }
}
