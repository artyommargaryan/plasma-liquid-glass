// SPDX-License-Identifier: GPL-3.0-or-later
// Recent notifications, newest first. A click runs the notification's default action; the cross removes it.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.components as PlasmaComponents

DetailPage {
    id: page
    title: i18n("Notifications")
    required property NotificationManager.Notifications history
    signal settingsRequested()

    trailing: TextPill {
        text: i18n("Clear")
        enabled: page.history.count > 0
        onClicked: page.history.clear(NotificationManager.Notifications.ClearExpired)
    }

    // notification bodies may carry simple markup; show them as plain text
    function plain(text: string): string {
        return text.replace(/<br\s*\/?>/gi, " ").replace(/<[^>]+>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<")
                   .replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/\s+/g, " ").trim();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Kirigami.Units.smallSpacing
            boundsBehavior: Flickable.StopAtBounds
            model: page.history

            delegate: Tile {
                id: row
                required property int index
                required property var model
                width: list.width
                height: Math.max(info.implicitHeight, appIcon.height) + Kirigami.Units.largeSpacing * 2
                hovered: rowArea.containsMouse

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: page.history.invokeDefaultAction(page.history.index(row.index, 0))
                }
                Kirigami.Icon {
                    id: appIcon
                    x: Kirigami.Units.largeSpacing
                    y: Kirigami.Units.largeSpacing
                    width: Kirigami.Units.iconSizes.medium
                    height: width
                    source: row.model.applicationIconName || row.model.iconName || "preferences-desktop-notification"
                }
                Column {
                    id: info
                    anchors {
                        left: appIcon.right
                        right: closeKnob.left
                        leftMargin: Kirigami.Units.largeSpacing
                        rightMargin: Kirigami.Units.smallSpacing
                        top: parent.top
                        topMargin: Kirigami.Units.largeSpacing
                    }
                    PlasmaComponents.Label {
                        width: parent.width
                        text: (row.model.applicationName || "") + (row.model.created ? " · " + Qt.formatTime(row.model.created, Qt.locale().timeFormat(Locale.ShortFormat)) : "")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    PlasmaComponents.Label {
                        width: parent.width
                        visible: text.length > 0
                        text: page.plain(row.model.summary || "")
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    PlasmaComponents.Label {
                        width: parent.width
                        visible: text.length > 0
                        text: page.plain(row.model.body || "")
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }
                Knob {
                    id: closeKnob
                    anchors.right: parent.right
                    anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                    y: Kirigami.Units.smallSpacing * 2
                    width: Kirigami.Units.gridUnit * 1.3
                    iconName: "window-close-symbolic"
                    pressed: closeArea.pressed
                    Accessible.role: Accessible.Button
                    Accessible.name: i18n("Remove")
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        onClicked: page.history.close(page.history.index(row.index, 0))
                    }
                }
            }

            PlasmaComponents.Label {
                anchors.centerIn: parent
                visible: list.count === 0
                opacity: 0.6
                text: i18n("No notifications")
            }

            PlasmaComponents.ScrollBar.vertical: PlasmaComponents.ScrollBar {}
        }

        TextPill {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("Notification Settings…")
            onClicked: page.settingsRequested()
        }
    }
}
