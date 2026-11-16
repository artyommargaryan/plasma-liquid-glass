// SPDX-License-Identifier: GPL-3.0-or-later
// A second-level page of the Control Center: a back button, a title, room for one control on the right,
// and the content underneath.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: page
    property string title
    property alias trailing: trailingSlot.data
    default property alias content: body.data
    signal back()

    Keys.onEscapePressed: page.back()

    RowLayout {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: Kirigami.Units.gridUnit * 2.2
        spacing: Kirigami.Units.largeSpacing

        Knob {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.9
            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.9
            iconName: "go-previous-symbolic"
            pressed: backArea.pressed
            Accessible.role: Accessible.Button
            Accessible.name: i18n("Back")
            MouseArea {
                id: backArea
                anchors.fill: parent
                onClicked: page.back()
            }
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: page.title
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
            elide: Text.ElideRight
        }
        Item {
            id: trailingSlot
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
        }
    }

    Item {
        id: body
        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: parent.bottom
            topMargin: Kirigami.Units.largeSpacing
        }
    }
}
