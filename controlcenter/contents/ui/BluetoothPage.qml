// SPDX-License-Identifier: GPL-3.0-or-later
// Bluetooth: the switch, and the paired devices to connect or disconnect with a click.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.bluezqt as BluezQt
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

DetailPage {
    id: page
    title: i18n("Bluetooth")
    signal settingsRequested()

    readonly property bool on: BluezQt.Manager.bluetoothOperational && !BluezQt.Manager.bluetoothBlocked
    // paired devices, the connected ones first, then by name
    readonly property var devices: {
        const list = [];
        const all = BluezQt.Manager.devices;
        for (let i = 0; i < all.length; ++i) {
            if (all[i].paired) {
                list.push(all[i]);
            }
        }
        list.sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name));
        return list;
    }

    trailing: Knob {
        width: Kirigami.Units.gridUnit * 1.9
        iconName: page.on ? "network-bluetooth-activated-symbolic" : "network-bluetooth-symbolic"
        on: page.on
        pressed: switchArea.pressed
        opacity: BluezQt.Manager.adapters.length > 0 ? 1 : 0.45
        Accessible.role: Accessible.CheckBox
        Accessible.name: i18n("Bluetooth")
        Accessible.checked: page.on
        MouseArea {
            id: switchArea
            anchors.fill: parent
            enabled: BluezQt.Manager.adapters.length > 0
            onClicked: BluezQt.Manager.bluetoothBlocked = !BluezQt.Manager.bluetoothBlocked
        }
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
            model: page.on ? page.devices : []

            delegate: Tile {
                id: row
                required property var modelData
                // true from the click until the device reports the new state, or the attempt gives up
                property bool busy: false
                width: list.width
                height: Kirigami.Units.gridUnit * 3
                hovered: rowArea.containsMouse

                Timer {
                    id: giveUp
                    interval: 20000
                    onTriggered: row.busy = false
                }
                Connections {
                    target: row.modelData
                    function onConnectedChanged() { row.busy = false; }
                }

                Knob {
                    id: deviceKnob
                    anchors.verticalCenter: parent.verticalCenter
                    x: Kirigami.Units.largeSpacing
                    width: Kirigami.Units.gridUnit * 2.1
                    iconName: (row.modelData.icon || "network-bluetooth") + "-symbolic"
                    on: row.modelData.connected
                    pressed: rowArea.pressed
                }
                Column {
                    anchors {
                        left: deviceKnob.right
                        right: parent.right
                        leftMargin: Kirigami.Units.largeSpacing
                        rightMargin: Kirigami.Units.largeSpacing
                        verticalCenter: parent.verticalCenter
                    }
                    PlasmaComponents.Label {
                        width: parent.width
                        text: row.modelData.name
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    PlasmaComponents.Label {
                        width: parent.width
                        text: {
                            if (row.busy) {
                                return row.modelData.connected ? i18n("Disconnecting…") : i18n("Connecting…");
                            }
                            if (!row.modelData.connected) {
                                return i18n("Not connected");
                            }
                            const battery = row.modelData.battery;
                            return battery ? i18n("Connected · %1%", battery.percentage) : i18n("Connected");
                        }
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !row.busy
                    onClicked: {
                        row.busy = true;
                        giveUp.restart();
                        if (row.modelData.connected) {
                            row.modelData.disconnectFromDevice();
                        } else {
                            row.modelData.connectToDevice();
                        }
                    }
                }
            }

            PlasmaComponents.Label {
                anchors.centerIn: parent
                width: parent.width
                visible: list.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.6
                text: BluezQt.Manager.adapters.length === 0 ? i18n("No Bluetooth adapter")
                    : !page.on ? i18n("Bluetooth is off")
                    : i18n("No paired devices. Pair one in Bluetooth Settings.")
            }
        }

        TextPill {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("Bluetooth Settings…")
            onClicked: page.settingsRequested()
        }
    }
}
