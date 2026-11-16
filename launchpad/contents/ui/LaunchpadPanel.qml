// SPDX-License-Identifier: GPL-3.0-or-later
// The Launchpad: a search pill and, under it, a panel with category pills, a favourites row and the app grid,
// centred on the screen of the button that opened it. Typing turns the panel into a list of results.
// The two are separate windows so each gets its own glass from the Plasma theme's dialog background; the search
// window holds the keyboard, and the pair closes when neither is the active window any more.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.clipboard as Clipboard
import org.kde.plasma.private.kicker as Kicker

PlasmaCore.Dialog {
    id: panel

    required property Kicker.RootModel rootModel
    required property Kicker.RunnerModel runnerModel
    required property Kicker.KAStatsFavoritesModel favorites
    property int columns: 7
    property int rows: 3
    property string previewQuery: ""

    readonly property int cellWidth: Kirigami.Units.gridUnit * 7
    readonly property int cellHeight: Kirigami.Units.iconSizes.huge + Kirigami.Units.gridUnit * 2 + Kirigami.Units.smallSpacing
    // the clipboard button of the search pill swaps apps for the clipboard history; the search then filters it
    property bool clipboardMode: false
    readonly property bool searching: !clipboardMode && search.text.length > 0
    readonly property Clipboard.HistoryModel clipboard: Clipboard.HistoryModel {}
    // the history model does not filter by text itself; this is the filter Plasma's own clipboard popup puts on it
    readonly property KItemModels.KSortFilterProxyModel clipboardFiltered: KItemModels.KSortFilterProxyModel {
        sourceModel: panel.clipboard
        filterRoleName: "display"
        // the text is matched literally, not as a pattern
        filterRegularExpression: RegExp(panel.clipboardMode ? search.text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") : "", "i")
    }
    // -1 = Favourites, otherwise a row of rootModel
    property int category: 0

    // modelForRow() is a plain call that bindings cannot follow, so the lookups are redone whenever the models
    // report a change (modelEpoch)
    property int modelEpoch: 0
    readonly property var gridModel: {
        modelEpoch;
        return category < 0 ? favorites : (rootModel.count > category ? rootModel.modelForRow(category) : null);
    }
    readonly property var resultsModel: {
        modelEpoch;
        return runnerModel.count > 0 ? runnerModel.modelForRow(0) : null;
    }
    readonly property Connections rootWatch: Connections {
        target: panel.rootModel
        function onRefreshed() { panel.modelEpoch++; }
        function onCountChanged() { panel.modelEpoch++; }
    }
    readonly property Connections runnerWatch: Connections {
        target: panel.runnerModel
        function onCountChanged() { panel.modelEpoch++; }
    }

    location: PlasmaCore.Types.Floating
    flags: Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: false

    property Item anchorItem: null
    readonly property int gap: Kirigami.Units.largeSpacing

    // the pair is centred on the screen of the button, a little above the middle; redone when sizes settle
    function place() {
        if (!anchorItem) {
            return;
        }
        const s = anchorItem.Screen;
        const total = searchWindow.height + gap + height;
        const top = s.virtualY + Math.max(Kirigami.Units.gridUnit * 3, Math.round((s.height - total) * 0.42));
        searchWindow.x = s.virtualX + Math.round((s.width - searchWindow.width) / 2);
        searchWindow.y = top;
        x = s.virtualX + Math.round((s.width - width) / 2);
        y = top + searchWindow.height + gap;
    }
    onWidthChanged: place()
    onHeightChanged: place()

    function open(anchor: Item) {
        anchorItem = anchor;
        clipboardMode = previewQuery === ":clipboard";
        search.text = clipboardMode ? "" : previewQuery;
        category = 0;
        grid.currentIndex = -1;
        grid.navigated = false;
        modelEpoch++;
        place();
        visible = true;
        searchWindow.visible = true;
        focusSearch();
    }
    function close() {
        searchWindow.visible = false;
        visible = false;
        search.text = "";
        clipboardMode = false;
    }

    function focusSearch() {
        searchWindow.requestActivate();
        search.forceActiveFocus();
    }

    function launch(model, index: int) {
        if (model && index >= 0 && index < model.count) {
            model.trigger(index, "", null);
            close();
        }
    }

    // Keys that mean the same wherever the keyboard is. Returns true when the key was used.
    function key(event): bool {
        switch (event.key) {
        case Qt.Key_Escape:
            if (search.text.length > 0) {
                search.text = "";
            } else if (clipboardMode) {
                clipboardMode = false;
            } else {
                close();
            }
            return true;
        case Qt.Key_Delete:
            if (clipboardMode && clips.currentItem) {
                clipboard.remove(clips.currentItem.uuid);
                return true;
            }
            return false;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (clipboardMode) {
                clips.pick(clips.currentIndex);
            } else if (searching) {
                launch(results.model, Math.max(0, results.currentIndex));
            } else {
                launch(grid.model, grid.currentIndex);
            }
            return true;
        case Qt.Key_Down:
            clipboardMode ? clips.move(1) : searching ? results.move(1) : grid.move(columns);
            return true;
        case Qt.Key_Up:
            clipboardMode ? clips.move(-1) : searching ? results.move(-1) : grid.move(-columns);
            return true;
        case Qt.Key_Tab:
            clipboardMode ? clips.move(1) : searching ? results.move(1) : grid.move(1);
            return true;
        case Qt.Key_Backtab:
            clipboardMode ? clips.move(-1) : searching ? results.move(-1) : grid.move(-1);
            return true;
        case Qt.Key_Right:
        case Qt.Key_Left:
            // in a search these move the text cursor; results are a list, walked with up and down
            if (searching || clipboardMode) {
                return false;
            }
            grid.move(event.key === Qt.Key_Right ? 1 : -1);
            return true;
        }
        return false;
    }

    // closes the pair once neither window is active (a click elsewhere, another window taking over)
    readonly property Timer closeCheck: Timer {
        interval: 150
        onTriggered: if (panel.visible && !panel.active && !searchWindow.active && !appMenu.open) {
            panel.close();
        }
    }
    onActiveChanged: closeCheck.restart()

    readonly property PlasmaCore.Dialog searchWindow: PlasmaCore.Dialog {
        id: searchWindow
        location: PlasmaCore.Types.Floating
        flags: Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: false
        onActiveChanged: panel.closeCheck.restart()
        onWidthChanged: panel.place()
        onHeightChanged: panel.place()

        mainItem: Item {
            width: Kirigami.Units.gridUnit * 30
            height: Kirigami.Units.gridUnit * 3

            Kirigami.Icon {
                id: searchIcon
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Kirigami.Units.largeSpacing
                width: Kirigami.Units.iconSizes.medium
                height: width
                source: "search"
                opacity: 0.8
            }

            TextInput {
                id: search
                anchors {
                    left: searchIcon.right
                    right: clipButton.left
                    leftMargin: Kirigami.Units.largeSpacing
                    rightMargin: Kirigami.Units.largeSpacing
                    verticalCenter: parent.verticalCenter
                }
                focus: true
                clip: true
                color: Kirigami.Theme.textColor
                selectionColor: Kirigami.Theme.highlightColor
                selectedTextColor: Kirigami.Theme.highlightedTextColor
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.6
                Accessible.name: i18n("Search applications")

                onTextChanged: {
                    if (!panel.clipboardMode) {
                        panel.runnerModel.query = text;
                    }
                    results.currentIndex = 0;
                    clips.currentIndex = 0;
                }
                Keys.onPressed: event => {
                    event.accepted = panel.key(event);
                }

                PlasmaComponents.Label {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: search.text.length === 0
                    text: panel.clipboardMode ? i18n("Clipboard") : i18n("Apps")
                    font: search.font
                    opacity: 0.55
                }
            }

            Rectangle {
                id: clipButton
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Kirigami.Units.smallSpacing
                width: Kirigami.Units.gridUnit * 2.2
                height: width
                radius: width / 2
                color: panel.clipboardMode ? Kirigami.Theme.highlightColor
                     : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, clipArea.containsMouse ? 0.16 : 0.0)
                Accessible.role: Accessible.Button
                Accessible.name: i18n("Clipboard history")

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    source: "edit-paste-symbolic"
                    isMask: true
                    color: panel.clipboardMode ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                }
                MouseArea {
                    id: clipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        panel.clipboardMode = !panel.clipboardMode;
                        search.forceActiveFocus();
                    }
                }
            }
        }
    }

    onClipboardModeChanged: {
        search.text = "";
        runnerModel.query = "";
        clips.currentIndex = 0;
    }

    mainItem: FocusScope {
        id: content
        width: panel.columns * panel.cellWidth + Kirigami.Units.gridUnit * 2
        height: browse.implicitHeight + Kirigami.Units.gridUnit * 2
        focus: true

        // A click in this window takes the keyboard away from the search window: keep typing working from here
        // and hand the keyboard back.
        Keys.onPressed: event => {
            if (panel.key(event)) {
                event.accepted = true;
            } else if (event.key === Qt.Key_Backspace) {
                search.text = search.text.slice(0, -1);
                event.accepted = true;
            } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                search.text += event.text;
                event.accepted = true;
            }
            if (event.accepted) {
                panel.focusSearch();
            }
        }

        // ---- browsing: category pills, favourites, grid ----
        ColumnLayout {
            id: browse
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.largeSpacing
            visible: !panel.searching && !panel.clipboardMode

            // wraps onto a second line rather than hiding categories off the edge
            Flow {
                id: pillRow
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Pill {
                    text: i18n("Favorites")
                    checked: panel.category === -1
                    onClicked: panel.category = -1
                }
                Repeater {
                    model: panel.rootModel
                    Pill {
                        required property int index
                        required property var model
                        text: index === 0 ? i18n("Apps") : (model.display ?? "")
                        checked: panel.category === index
                        onClicked: panel.category = index
                    }
                }
            }

            // favourites row, above the grid on every category
            ListView {
                id: favRow
                Layout.fillWidth: true
                Layout.preferredHeight: panel.cellHeight
                visible: panel.category >= 0 && count > 0
                orientation: ListView.Horizontal
                interactive: false
                clip: true
                model: panel.favorites
                delegate: AppCell {
                    width: grid.cellWidth
                    height: panel.cellHeight
                    onActivated: panel.launch(panel.favorites, index)
                    onMenuRequested: appMenu.show(this, model.favoriteId)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                visible: favRow.visible
                color: Kirigami.Theme.textColor
                opacity: 0.12
            }

            GridView {
                id: grid

                // true once the arrow keys have moved the selection
                property bool navigated: false

                Layout.fillWidth: true
                Layout.preferredHeight: panel.cellHeight * panel.rows
                // exactly `columns` across whatever the rounding of the width
                cellWidth: Math.floor(width / panel.columns)
                cellHeight: panel.cellHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: -1
                model: panel.gridModel
                onModelChanged: {
                    navigated = false;
                    currentIndex = -1;
                }

                function move(step: int) {
                    if (count === 0) {
                        return;
                    }
                    navigated = true;
                    currentIndex = currentIndex < 0 ? 0 : Math.max(0, Math.min(count - 1, currentIndex + step));
                    positionViewAtIndex(currentIndex, GridView.Contain);
                }

                delegate: AppCell {
                    width: grid.cellWidth
                    height: panel.cellHeight
                    current: GridView.isCurrentItem
                    onActivated: panel.launch(grid.model, index)
                    onMenuRequested: appMenu.show(this, model.favoriteId)
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    visible: grid.count === 0 && panel.category < 0
                    opacity: 0.6
                    text: i18n("Right-click an app to add it to Favorites")
                }

                PlasmaComponents.ScrollBar.vertical: PlasmaComponents.ScrollBar {}
            }
        }

        // ---- searching: a list of results, the top one selected ----
        ListView {
            id: results
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit
            visible: panel.searching
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: panel.searching ? panel.resultsModel : null
            currentIndex: 0
            highlightMoveDuration: 0
            onCountChanged: if (currentIndex < 0 || currentIndex >= count) {
                currentIndex = 0;
            }

            function move(step: int) {
                if (count === 0) {
                    return;
                }
                currentIndex = Math.max(0, Math.min(count - 1, currentIndex + step));
                positionViewAtIndex(currentIndex, ListView.Contain);
            }

            section.property: "group"
            section.delegate: RowLayout {
                id: header
                required property string section
                width: results.width
                height: Kirigami.Units.gridUnit * 1.6
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Label {
                    text: header.section
                    font.bold: true
                    opacity: 0.75
                    textFormat: Text.PlainText
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Kirigami.Theme.textColor
                    opacity: 0.15
                }
            }

            delegate: Item {
                id: row
                required property int index
                required property var model
                width: results.width - (resultScroll.visible ? resultScroll.width + Kirigami.Units.smallSpacing : 0)
                height: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 4

                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.gridUnit * 0.6
                    color: Kirigami.Theme.textColor
                    opacity: row.ListView.isCurrentItem ? 0.14 : 0
                }
                Kirigami.Icon {
                    id: rowIcon
                    anchors.verticalCenter: parent.verticalCenter
                    x: Kirigami.Units.largeSpacing
                    width: Kirigami.Units.iconSizes.medium
                    height: width
                    source: row.model.decoration
                }
                Column {
                    anchors {
                        left: rowIcon.right
                        right: parent.right
                        leftMargin: Kirigami.Units.largeSpacing
                        rightMargin: Kirigami.Units.largeSpacing
                        verticalCenter: parent.verticalCenter
                    }
                    PlasmaComponents.Label {
                        width: parent.width
                        text: row.model.display ?? ""
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    PlasmaComponents.Label {
                        width: parent.width
                        visible: text.length > 0
                        text: row.model.description ?? ""
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPositionChanged: results.currentIndex = row.index
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            appMenu.show(row, row.model.favoriteId);
                        } else {
                            panel.launch(results.model, row.index);
                        }
                    }
                }
            }

            PlasmaComponents.Label {
                anchors.centerIn: parent
                visible: results.count === 0 && !panel.runnerModel.querying
                opacity: 0.6
                text: i18n("No matches")
            }

            PlasmaComponents.ScrollBar.vertical: PlasmaComponents.ScrollBar { id: resultScroll }
        }

        // ---- clipboard history: pick an entry to make it the current clipboard ----
        ListView {
            id: clips
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit
            visible: panel.clipboardMode
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: panel.clipboardMode ? panel.clipboardFiltered : null
            currentIndex: 0
            highlightMoveDuration: 0
            onCountChanged: if (currentIndex < 0 || currentIndex >= count) {
                currentIndex = 0;
            }

            function move(step: int) {
                if (count === 0) {
                    return;
                }
                currentIndex = Math.max(0, Math.min(count - 1, currentIndex + step));
                positionViewAtIndex(currentIndex, ListView.Contain);
            }
            function pick(index: int) {
                if (index < 0 || index >= count) {
                    return;
                }
                const item = itemAtIndex(index);
                if (item) {
                    panel.clipboard.moveToTop(item.uuid);
                    panel.close();
                }
            }

            header: PlasmaComponents.Label {
                width: clips.width
                height: Kirigami.Units.gridUnit * 1.6
                verticalAlignment: Text.AlignTop
                text: i18n("Clipboard history — Enter copies the selected entry, Delete removes it")
                font: Kirigami.Theme.smallFont
                opacity: 0.6
                elide: Text.ElideRight
            }

            delegate: Item {
                id: clipRow
                required property int index
                required property var model
                required property var uuid
                required property var decoration
                required property size imageSize
                readonly property bool isImage: imageSize.width > 0 && imageSize.height > 0
                // rows stop short of the scroll bar, so it never covers the remove button
                width: clips.width - (clipScroll.visible ? clipScroll.width + Kirigami.Units.smallSpacing : 0)
                height: (isImage ? preview.height : clipText.implicitHeight) + Kirigami.Units.smallSpacing * 4

                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.gridUnit * 0.6
                    color: Kirigami.Theme.textColor
                    opacity: clipRow.ListView.isCurrentItem ? 0.14 : 0
                }
                PlasmaComponents.Label {
                    id: clipText
                    visible: !clipRow.isImage
                    anchors {
                        left: parent.left
                        right: removeButton.left
                        leftMargin: Kirigami.Units.largeSpacing
                        rightMargin: Kirigami.Units.smallSpacing
                        verticalCenter: parent.verticalCenter
                    }
                    // long entries are cut before layout, they can be megabytes
                    text: (clipRow.model.display ?? "").slice(0, 400).trim()
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                Image {
                    id: preview
                    visible: clipRow.isImage
                    x: Kirigami.Units.largeSpacing
                    anchors.verticalCenter: parent.verticalCenter
                    height: Kirigami.Units.gridUnit * 4
                    width: clipRow.isImage ? Math.min(Math.round(height * clipRow.imageSize.width / clipRow.imageSize.height), parent.width - Kirigami.Units.gridUnit * 4) : 0
                    source: clipRow.isImage ? clipRow.decoration : ""
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    asynchronous: true
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: clips.currentIndex = clipRow.index
                    onClicked: clips.pick(clipRow.index)
                }
                Rectangle {
                    id: removeButton
                    anchors.right: parent.right
                    anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: Kirigami.Units.gridUnit * 1.4
                    height: width
                    radius: width / 2
                    visible: clipRow.ListView.isCurrentItem
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, removeArea.containsMouse ? 0.25 : 0.12)
                    Accessible.role: Accessible.Button
                    Accessible.name: i18n("Remove")
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.small
                        height: width
                        source: "window-close-symbolic"
                        isMask: true
                        color: Kirigami.Theme.textColor
                    }
                    MouseArea {
                        id: removeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: panel.clipboard.remove(clipRow.uuid)
                    }
                }
            }

            PlasmaComponents.Label {
                anchors.centerIn: parent
                visible: clips.count === 0
                opacity: 0.6
                text: search.text.length > 0 ? i18n("No matches") : i18n("The clipboard history is empty")
            }

            PlasmaComponents.ScrollBar.vertical: PlasmaComponents.ScrollBar { id: clipScroll }
        }

        PlasmaExtras.Menu {
            id: appMenu
            property string favoriteId: ""
            property bool open: false
            readonly property bool isFavorite: favoriteId.length > 0 && panel.favorites.isFavorite(favoriteId)

            function show(item: Item, id) {
                if (!id) {
                    return;
                }
                favoriteId = id;
                visualParent = item;
                placement = PlasmaExtras.Menu.BottomPosedRightAlignedPopup;
                open = true;
                openRelative();
            }
            onStatusChanged: if (status === PlasmaExtras.Menu.Closed) {
                open = false;
                panel.focusSearch();
            }

            PlasmaExtras.MenuItem {
                text: appMenu.isFavorite ? i18n("Remove from Favorites") : i18n("Add to Favorites")
                icon: appMenu.isFavorite ? "bookmark-remove" : "bookmark-new"
                onClicked: {
                    if (appMenu.isFavorite) {
                        panel.favorites.removeFavorite(appMenu.favoriteId);
                    } else {
                        panel.favorites.addFavorite(appMenu.favoriteId);
                    }
                }
            }
        }
    }

    component Pill: Rectangle {
        id: pill
        property alias text: label.text
        property bool checked: false
        signal clicked()

        implicitWidth: label.implicitWidth + Kirigami.Units.gridUnit * 1.2
        implicitHeight: label.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: height / 2
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                       checked ? 0.22 : (pillArea.containsMouse ? 0.14 : 0.07))

        PlasmaComponents.Label {
            id: label
            anchors.centerIn: parent
            textFormat: Text.PlainText
        }
        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: pill.clicked()
        }
    }
}
