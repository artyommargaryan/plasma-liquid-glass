// SPDX-License-Identifier: GPL-3.0-or-later
// Launchpad (Liquid Glass): a panel button that opens a centred glass panel with search, category pills,
// a favourites row and an app grid. Pure QML on top of Plasma's own launcher models
// (org.kde.plasma.private.kicker), so there is nothing to compile.
pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: root

    readonly property Kicker.KAStatsFavoritesModel favorites: rootModel.favoritesModel as Kicker.KAStatsFavoritesModel

    preferredRepresentation: fullRepresentation
    Plasmoid.icon: Plasmoid.configuration.icon
    toolTipMainText: i18n("Launchpad")
    toolTipSubText: i18n("Find and open applications")

    // the "full" representation is just the button; the panel is a window of its own
    fullRepresentation: MouseArea {
        id: button
        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        implicitWidth: vertical ? -1 : height
        implicitHeight: vertical ? width : -1
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: i18n("Launchpad")
        onClicked: root.toggle()
        Keys.onReturnPressed: root.toggle()
        Keys.onSpacePressed: root.toggle()
        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: button.containsMouse
        }
    }

    function toggle() {
        if (panel.visible) {
            panel.close();
        } else {
            rootModel.refresh();
            panel.open(root);
        }
    }

    Plasmoid.onActivated: toggle()

    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        appNameFormat: 0
        flat: true
        sorted: true
        showSeparators: false
        showRootSeparator: false
        appletInterface: root
        showAllApps: true
        showAllAppsCategorized: false
        showTopLevelItems: false
        showRecentApps: false
        showRecentDocs: false
        showRecentFolders: false
        showPowerSession: false
        showFavoritesPlaceholder: false
        Component.onCompleted: {
            (favoritesModel as Kicker.KAStatsFavoritesModel).initForClient("org.kde.plasma.kicker.favorites.instance-" + Plasmoid.id);
            refresh();
        }
    }

    Kicker.RunnerModel {
        id: runnerModel
        appletInterface: root
        favoritesModel: root.favorites
        mergeResults: true
        runners: ["krunner_services", "krunner_systemsettings", "krunner_sessions", "krunner_powerdevil", "calculator", "unitconverter"]
    }

    Kicker.ProcessRunner {
        id: processRunner
    }

    LaunchpadPanel {
        id: panel
        rootModel: rootModel
        runnerModel: runnerModel
        favorites: root.favorites
        columns: Plasmoid.configuration.columns
        rows: Plasmoid.configuration.rows
        previewQuery: Plasmoid.configuration.previewQuery
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Edit Applications…")
            icon.name: "kmenuedit"
            onTriggered: processRunner.runMenuEditor()
        }
    ]

    Component.onCompleted: {
        if (Plasmoid.hasOwnProperty("activationTogglesExpanded")) {
            Plasmoid.activationTogglesExpanded = false;
        }
    }
}
