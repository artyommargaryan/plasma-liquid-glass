// SPDX-License-Identifier: GPL-3.0-or-later
// Control Center (Liquid Glass): a panel button whose popup gathers the everyday switches and sliders -
// network, Bluetooth, Do Not Disturb, dark mode, the playing media, screen brightness and volume.
// Pure QML on the modules Plasma's own widgets use, so nothing is compiled; the glass is the popup background
// of the Plasma theme.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.bluezqt as BluezQt
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.plasmoid
import org.kde.plasma.private.brightnesscontrolplugin as Brightness
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.volume as Volume

PlasmoidItem {
    id: root

    Plasmoid.icon: Plasmoid.configuration.icon.length > 0 ? Plasmoid.configuration.icon : "configure"
    toolTipMainText: i18n("Control Center")

    // the button: the widget's own two-switches icon unless the config names another one
    compactRepresentation: MouseArea {
        id: button
        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        implicitWidth: vertical ? -1 : height
        implicitHeight: vertical ? width : -1
        Layout.minimumWidth: vertical ? -1 : height
        Layout.minimumHeight: vertical ? width : -1
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: i18n("Control Center")
        onClicked: root.toggle()
        Keys.onReturnPressed: root.toggle()
        Keys.onSpacePressed: root.toggle()

        readonly property bool own: Plasmoid.configuration.icon.length === 0
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height, Kirigami.Units.iconSizes.smallMedium)
            height: width
            source: button.own ? Qt.resolvedUrl("../icons/control-center.svg") : Plasmoid.configuration.icon
            isMask: button.own
            color: Kirigami.Theme.textColor
            active: button.containsMouse
            opacity: button.containsMouse || root.shown ? 1 : 0.9
        }
    }
    toolTipSubText: i18n("Network, sound, display and more")

    // one grid unit of the tile layout, and the gap between tiles
    readonly property int unit: Kirigami.Units.gridUnit * 4.4
    readonly property int gap: Kirigami.Units.largeSpacing

    function openSettings(module: string) {
        KCMUtils.KCMLauncher.openSystemSettings(module);
        root.hide();
    }

    // Two ways of showing the controls. With the compiled module org.liquidglass.shape (glass-shape/) they float:
    // a window without a background in which every tile is a piece of glass of its own. Without it they sit in
    // the widget's ordinary popup, on the theme's glass panel.
    readonly property bool floating: {
        try {
            Qt.createQmlObject("import org.liquidglass.shape; GlassShape {}", root, "probe").destroy();
            return Plasmoid.configuration.floatingTiles;
        } catch (e) {
            return false;
        }
    }
    readonly property bool shown: floating ? floatDialog.visible : root.expanded
    function show() {
        if (floating) {
            floatDialog.visible = true;
            floatDialog.requestActivate();
        } else {
            root.expanded = true;
        }
    }
    function hide() {
        floatDialog.visible = false;
        root.expanded = false;
    }
    function toggle() {
        shown ? hide() : show();
    }
    Plasmoid.onActivated: if (floating) {
        toggle();
    }
    // anything that still opens the ordinary popup (a shortcut, the panel) is turned into the floating window
    onExpandedChanged: if (floating && root.expanded) {
        root.expanded = false;
        show();
    }

    PlasmaCore.Dialog {
        id: floatDialog
        // read by the tiles (Tile.qml) to know they have to bring their own glass
        property bool glassTiles: true
        visualParent: root
        location: Plasmoid.location
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: !Plasmoid.configuration.previewOpen
        flags: Qt.WindowStaysOnTopHint
        mainItem: Item {
            // a little air between the tiles and the panel and screen edges
            readonly property int pad: Kirigami.Units.largeSpacing
            width: (floatLoader.item ? floatLoader.item.Layout.preferredWidth : 1) + pad * 2
            height: (floatLoader.item ? floatLoader.item.Layout.preferredHeight : 1) + pad * 2
            Keys.onEscapePressed: root.page.length > 0 ? root.page = "" : root.hide()
            Loader {
                id: floatLoader
                anchors.fill: parent
                anchors.margins: parent.pad
                active: root.floating
                sourceComponent: contentComponent
            }
        }
    }

    PlasmaNM.AvailableDevices { id: netDevices }
    PlasmaNM.EnabledConnections { id: netEnabled }
    PlasmaNM.ConnectionIcon { id: netIcon }
    PlasmaNM.NetworkStatus { id: netStatus }
    PlasmaNM.Handler { id: netHandler }
    NotificationManager.Settings { id: notifications }
    Brightness.ScreenBrightnessControl { id: screens }
    Mpris.Mpris2Model { id: players }
    NotificationManager.Notifications {
        id: history
        limit: 40
        showExpired: true
        showDismissed: true
        showNotifications: true
        showJobs: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
    }

    // "" = the tiles, otherwise the name of the detail page on show
    property string page: ""
    // always back on the tiles the next time it opens
    onShownChanged: if (!root.shown) {
        root.page = Plasmoid.configuration.previewOpen ? Plasmoid.configuration.previewPage : "";
    }
    Component.onCompleted: if (Plasmoid.configuration.previewOpen) {
        page = Plasmoid.configuration.previewPage;
    }

    // Do Not Disturb ends at a point in time; this makes the tile notice when that point passes
    property date now: new Date()
    Timer {
        interval: 30000
        running: root.shown
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Timer {
        // the popup closes again whenever another window is active, so keep reopening it
        interval: 1000
        repeat: true
        running: Plasmoid.configuration.previewOpen
        onTriggered: root.show()
    }

    fullRepresentation: contentComponent
    Component {
        id: contentComponent
        Item {
        id: full
        readonly property var sink: Volume.PreferredDevice.sink
        readonly property var player: Plasmoid.configuration.previewHideMedia ? null : players.currentPlayer
        readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
        // tiles are sized from the width the popup really gives, so they always fit it
        readonly property real unit: Math.floor((width - root.gap * 3) / 4)
        readonly property bool dnd: notifications.notificationsInhibitedUntil > root.now || notifications.notificationsInhibitedByApplication

        Layout.preferredWidth: root.unit * 4 + root.gap * 3
        Layout.preferredHeight: column.implicitHeight
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumWidth: Layout.preferredWidth
        Layout.maximumHeight: Layout.preferredHeight

        BluetoothPage {
            anchors.fill: parent
            visible: root.page === "bluetooth"
            onBack: root.page = ""
            onSettingsRequested: root.openSettings("kcm_bluetooth")
        }
        NotificationsPage {
            anchors.fill: parent
            visible: root.page === "notifications"
            history: history
            onVisibleChanged: if (visible) {
                history.lastRead = new Date();
            }
            onBack: root.page = ""
            onSettingsRequested: root.openSettings("kcm_notifications")
        }

        ColumnLayout {
            id: column
            anchors.fill: parent
            spacing: root.gap
            visible: root.page === ""

            // ---- switches on the left, the playing media on the right ----
            RowLayout {
                Layout.fillWidth: true
                spacing: root.gap

                ColumnLayout {
                    spacing: root.gap

                    // Wi-Fi where there is a wireless card; otherwise the state of the wired network, which
                    // is shown, not switched: turning networking off from a tile is too easy to do by accident
                    ToggleTile {
                        Layout.preferredWidth: full.unit * 2 + root.gap
                        Layout.preferredHeight: full.unit
                        readonly property bool wifi: netDevices.wirelessDeviceAvailable
                        iconName: wifi ? (netEnabled.wirelessEnabled ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic")
                                       : "network-wired-symbolic"
                        title: wifi ? i18n("Wi-Fi") : i18n("Network")
                        on: wifi ? netEnabled.wirelessEnabled : netStatus.activeConnections.length > 0
                        status: {
                            if (wifi && !netEnabled.wirelessEnabled) {
                                return i18n("Off");
                            }
                            const active = netStatus.activeConnections;
                            return active.length > 0 ? active : i18n("Not connected");
                        }
                        enabled: !wifi || netEnabled.wirelessHwEnabled
                        onClicked: wifi ? netHandler.enableWireless(!netEnabled.wirelessEnabled) : root.openSettings("kcm_networkmanagement")
                    }

                    RowLayout {
                        spacing: root.gap

                        ToggleTile {
                            Layout.preferredWidth: full.unit
                            Layout.preferredHeight: full.unit
                            iconName: on ? "network-bluetooth-activated-symbolic" : "network-bluetooth-symbolic"
                            title: i18n("Bluetooth")
                            on: BluezQt.Manager.bluetoothOperational && !BluezQt.Manager.bluetoothBlocked
                            status: !enabled ? i18n("No adapter") : (on ? i18np("%1 device connected", "%1 devices connected", BluezQt.Manager.connectedDevices.length) : i18n("Off"))
                            // the knob switches Bluetooth; the rest of the tile opens the switch and paired devices
                            splitKnob: BluezQt.Manager.adapters.length > 0
                            onKnobClicked: BluezQt.Manager.bluetoothBlocked = !BluezQt.Manager.bluetoothBlocked
                            onClicked: root.page = "bluetooth"
                        }

                        ToggleTile {
                            Layout.preferredWidth: full.unit
                            Layout.preferredHeight: full.unit
                            iconName: "weather-clear-night-symbolic"
                            title: i18n("Dark Mode")
                            on: Brightness.DarkModeControl.darkMode
                            status: on ? i18n("On") : i18n("Off")
                            onClicked: Brightness.DarkModeControl.darkMode = !Brightness.DarkModeControl.darkMode
                        }
                    }
                }

                Tile {
                    id: media
                    Layout.preferredWidth: full.unit * 2 + root.gap
                    Layout.preferredHeight: full.unit * 2 + root.gap
                    radius: Kirigami.Units.gridUnit * 1.4

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing * 1.5
                        spacing: Kirigami.Units.smallSpacing

                        Rectangle {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                            radius: Kirigami.Units.gridUnit * 0.6
                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                            clip: true
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Kirigami.Units.iconSizes.smallMedium
                                height: width
                                source: "folder-music-symbolic"
                                isMask: true
                                color: Kirigami.Theme.textColor
                                visible: cover.status !== Image.Ready
                            }
                            Image {
                                id: cover
                                anchors.fill: parent
                                source: full.player?.artUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(128, 128)
                            }
                        }
                        Item { Layout.fillHeight: true }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: full.player ? (full.player.track || full.player.identity) : i18n("Nothing playing")
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: full.player?.artist ?? ""
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            MediaButton {
                                iconName: "media-skip-backward-symbolic"
                                text: i18n("Previous track")
                                enabled: !!full.player && full.player.canGoPrevious
                                onClicked: full.player.Previous()
                            }
                            MediaButton {
                                iconName: full.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                                text: full.playing ? i18n("Pause") : i18n("Play")
                                enabled: !!full.player && (full.playing ? full.player.canPause : full.player.canPlay)
                                onClicked: full.player.PlayPause()
                            }
                            MediaButton {
                                iconName: "media-skip-forward-symbolic"
                                text: i18n("Next track")
                                enabled: !!full.player && full.player.canGoNext
                                onClicked: full.player.Next()
                            }
                        }
                    }
                }
            }

            // ---- Do Not Disturb, and the way into the full settings ----
            RowLayout {
                Layout.fillWidth: true
                spacing: root.gap

                ToggleTile {
                    Layout.preferredWidth: full.unit * 2 + root.gap
                    Layout.preferredHeight: full.unit
                    iconName: "notifications-disabled-symbolic"
                    title: i18n("Do Not Disturb")
                    on: full.dnd
                    status: notifications.notificationsInhibitedByApplication ? i18n("Set by an application")
                          : on ? i18n("Until %1", Qt.formatTime(notifications.notificationsInhibitedUntil, Qt.locale().timeFormat(Locale.ShortFormat)))
                          : i18n("Off")
                    enabled: !notifications.notificationsInhibitedByApplication
                    onClicked: {
                        // one hour, like the button of Plasma's own notifications widget
                        notifications.notificationsInhibitedUntil = on ? new Date(0) : new Date(Date.now() + 3600000);
                        notifications.save();
                        root.now = new Date();
                    }
                }
                ToggleTile {
                    Layout.preferredWidth: full.unit
                    Layout.preferredHeight: full.unit
                    iconName: "notifications-symbolic"
                    title: i18n("Notifications")
                    on: history.unreadNotificationsCount > 0
                    status: history.count === 0 ? i18n("None") : i18np("%1 notification", "%1 notifications", history.count)
                    onClicked: root.page = "notifications"
                }
                ToggleTile {
                    Layout.preferredWidth: full.unit
                    Layout.preferredHeight: full.unit
                    iconName: "configure-symbolic"
                    title: i18n("System Settings")
                    onClicked: root.openSettings("")
                }
            }

            // ---- display brightness, one bar per screen that can be dimmed ----
            Tile {
                Layout.fillWidth: true
                Layout.preferredHeight: displayColumn.implicitHeight + Kirigami.Units.largeSpacing * 3
                visible: screens.isBrightnessAvailable
                radius: Kirigami.Units.gridUnit * 1.4

                ColumnLayout {
                    id: displayColumn
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing * 1.5
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: i18n("Display")
                        font.weight: Font.DemiBold
                    }
                    Repeater {
                        id: displayRepeater
                        model: screens.displays
                        ColumnLayout {
                            id: display
                            required property var model
                            Layout.fillWidth: true
                            spacing: 2
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                visible: displayRepeater.count > 1
                                text: display.model.label || display.model.displayName
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                            SlideBar {
                                Layout.fillWidth: true
                                iconName: "brightness-high-symbolic"
                                from: 0
                                to: display.model.maxBrightness
                                value: display.model.brightness
                                Accessible.name: i18n("Brightness of %1", display.model.label || display.model.displayName)
                                onMoved: value => screens.setBrightness(display.model.displayName, Math.round(value))
                            }
                        }
                    }
                }
            }

            // ---- volume of the output in use ----
            Tile {
                Layout.fillWidth: true
                Layout.preferredHeight: soundColumn.implicitHeight + Kirigami.Units.largeSpacing * 3
                radius: Kirigami.Units.gridUnit * 1.4

                ColumnLayout {
                    id: soundColumn
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing * 1.5
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: i18n("Sound")
                        font.weight: Font.DemiBold
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing
                        SlideBar {
                            Layout.fillWidth: true
                            enabled: !!full.sink
                            iconName: !full.sink || full.sink.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                            from: 0
                            to: Volume.PulseAudio.NormalVolume
                            value: full.sink && !full.sink.muted ? full.sink.volume : 0
                            Accessible.name: i18n("Volume")
                            onMoved: value => {
                                full.sink.volume = Math.round(value);
                                full.sink.muted = value <= 0;
                            }
                        }
                        Knob {
                            id: micKnob
                            readonly property var source: Volume.PreferredDevice.source
                            width: Kirigami.Units.gridUnit * 1.5
                            visible: !!source
                            iconName: on ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic"
                            on: !!source && source.muted
                            pressed: micArea.pressed
                            Accessible.role: Accessible.Button
                            Accessible.name: i18n("Mute microphone")
                            MouseArea {
                                id: micArea
                                anchors.fill: parent
                                onClicked: micKnob.source.muted = !micKnob.source.muted
                            }
                        }
                        Knob {
                            width: Kirigami.Units.gridUnit * 1.5
                            iconName: "audio-volume-muted-symbolic"
                            on: !!full.sink && full.sink.muted
                            pressed: muteArea.pressed
                            opacity: full.sink ? 1 : 0.45
                            Accessible.role: Accessible.Button
                            Accessible.name: i18n("Mute")
                            MouseArea {
                                id: muteArea
                                anchors.fill: parent
                                enabled: !!full.sink
                                onClicked: full.sink.muted = !full.sink.muted
                            }
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: full.sink ? full.sink.description : i18n("No audio output")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }
            }
        }
    }
    }

    component MediaButton: Item {
        id: mediaButton
        property string iconName
        property string text
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.8
        opacity: enabled ? 1 : 0.35
        Accessible.role: Accessible.Button
        Accessible.name: text
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.smallMedium
            height: width
            source: mediaButton.iconName
            isMask: true
            color: Kirigami.Theme.textColor
            scale: mediaArea.pressed ? 0.85 : 1
            Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }
        MouseArea {
            id: mediaArea
            anchors.fill: parent
            onClicked: mediaButton.clicked()
        }
    }
}
