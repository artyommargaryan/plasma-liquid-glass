// SPDX-License-Identifier: GPL-3.0-or-later
// System Menu (Liquid Glass): a logo button at the start of the top bar whose menu holds what concerns the
// whole computer - about, settings, software, force quit, sleep, restart, shut down, lock and log out.
// A native menu, so it is drawn (and made glass) like every other menu of the desktop.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid
import org.kde.plasma.private.sessions as Sessions
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.icon: Plasmoid.configuration.icon
    toolTipMainText: i18n("System Menu")
    toolTipSubText: i18n("About, settings, sleep, restart, shut down")

    Sessions.SessionManagement { id: session }

    // runs a command line; used for the one entry that starts an application
    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => disconnectSource(source)
    }

    function toggle(button: Item) {
        if (menu.status === PlasmaExtras.Menu.Open) {
            menu.close();
        } else {
            menu.visualParent = button;
            menu.placement = PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
            menu.openRelative();
        }
    }

    fullRepresentation: MouseArea {
        id: button
        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        implicitWidth: vertical ? -1 : height
        implicitHeight: vertical ? width : -1
        Layout.minimumWidth: vertical ? -1 : height
        Layout.minimumHeight: vertical ? width : -1
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.role: Accessible.ButtonMenu
        Accessible.name: i18n("System Menu")
        onClicked: root.toggle(button)
        Keys.onReturnPressed: root.toggle(button)
        Keys.onSpacePressed: root.toggle(button)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.textColor
            opacity: menu.status === PlasmaExtras.Menu.Open ? 0.18 : (button.containsMouse ? 0.10 : 0)
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height, Kirigami.Units.iconSizes.smallMedium)
            height: width
            source: Plasmoid.icon
        }

        Timer {
            // opens once, and closes again by itself so the menu never keeps hold of the pointer
            interval: 1500
            running: Plasmoid.configuration.previewOpen
            onTriggered: {
                root.toggle(button);
                previewClose.start();
            }
        }
        Timer {
            id: previewClose
            interval: 5000
            onTriggered: menu.close()
        }
    }

    Plasmoid.onActivated: if (fullRepresentationItem) {
        toggle(fullRepresentationItem);
    }

    PlasmaExtras.Menu {
        id: menu

        PlasmaExtras.MenuItem {
            text: i18n("About This Computer")
            icon: "computer-symbolic"
            onClicked: KCMUtils.KCMLauncher.openInfoCenter("kcm_about-distro")
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: i18n("System Settings…")
            icon: "configure-symbolic"
            onClicked: KCMUtils.KCMLauncher.openSystemSettings("")
        }
        PlasmaExtras.MenuItem {
            text: i18n("Software…")
            icon: "plasmadiscover-symbolic"
            visible: Plasmoid.configuration.softwareCommand.length > 0
            onClicked: runner.connectSource(Plasmoid.configuration.softwareCommand)
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            // KWin's "kill window": the pointer becomes a cross, the window clicked next is closed by force
            text: i18n("Force Quit…")
            icon: "process-stop-symbolic"
            onClicked: DBus.SessionBus.asyncCall({service: "org.kde.KWin", path: "/KWin", iface: "org.kde.KWin", member: "killWindow"})
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: i18n("Sleep")
            icon: "system-suspend-symbolic"
            visible: session.canSuspend
            onClicked: session.suspend()
        }
        PlasmaExtras.MenuItem {
            text: i18n("Restart…")
            icon: "system-reboot-symbolic"
            visible: session.canReboot
            onClicked: session.requestReboot()
        }
        PlasmaExtras.MenuItem {
            text: i18n("Shut Down…")
            icon: "system-shutdown-symbolic"
            visible: session.canShutdown
            onClicked: session.requestShutdown()
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: i18n("Lock Screen")
            icon: "system-lock-screen-symbolic"
            visible: session.canLock
            onClicked: session.lock()
        }
        PlasmaExtras.MenuItem {
            text: i18n("Log Out…")
            icon: "system-log-out-symbolic"
            visible: session.canLogout
            onClicked: session.requestLogout()
        }
    }
}
