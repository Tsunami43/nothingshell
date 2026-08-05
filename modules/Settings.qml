// Settings — a regular xdg-toplevel, so the compositor moves, resizes and lists it. Opened from
// the launcher's Settings entry, a ">" command, or `ipc call settings open <page>`.
//
// Left nav pane (grouped, filterable) + one lazily-loaded page. The page list lives in
// settings/PageRegistry.qml and `pageComps` below is index-aligned with it. Only the visible page
// exists at a time: several own polling processes a StackLayout would all start at once.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import qs.modules.settings
import qs.modules.settings.common
import qs.modules.settings.pages

FloatingWindow {
    id: win
    visible: Shell.settingsVisible
    // The compositor's close button fires `closed`; hide (don't destroy) so it can reopen.
    onClosed: Shell.settingsVisible = false
    title: "Settings"
    implicitWidth: 1040
    implicitHeight: 680
    minimumSize: Qt.size(780, 500)
    color: Config.surface

    property int page: 0
    property string filter: ""

    // Deep-link: Shell.openSettings("network") sets a page id, consumed and cleared here so a
    // later plain open resumes the last page viewed.
    onVisibleChanged: {
        if (!win.visible) return;
        const i = PageRegistry.indexOf(Shell.settingsPage);
        if (i >= 0) win.page = i;
        Shell.settingsPage = "";
        win.filter = "";
    }
    Connections {
        target: Shell
        // On an already-open window onVisibleChanged never fires again, so move the page here.
        function onSettingsPageChanged() {
            if (!win.visible || !Shell.settingsPage) return;
            const i = PageRegistry.indexOf(Shell.settingsPage);
            if (i >= 0) win.page = i;
            Shell.settingsPage = "";
        }
    }

    // Nav entries surviving the filter, each carrying its true PageRegistry.pages index so
    // filtering can't desync the click target from the page component.
    readonly property var navModel: {
        const q = win.filter.trim().toLowerCase();
        const out = [];
        for (let i = 0; i < PageRegistry.pages.length; i++) {
            const p = PageRegistry.pages[i];
            if (q && !(p.label + " " + p.desc + " " + p.id + " " + p.category).toLowerCase().includes(q)) continue;
            out.push({ p: p, idx: i, catStart: out.length === 0 || out[out.length - 1].p.category !== p.category });
        }
        return out;
    }

    // Index-aligned with PageRegistry.pages.
    readonly property list<Component> pageComps: [
        Component { AppearancePage {} },
        Component { DisplaysPage {} },
        Component { AudioPage {} },
        Component { BluetoothPage {} },
        Component { NetworkPage {} },
        Component { VpnPage {} },
        Component { LanguagePage {} },
        Component { PowerPage {} },
        Component { ShellPage {} },
        Component { NotifsPage {} },
        Component { CapturePage {} },
        Component { AboutPage {} }
    ]

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Shell.settingsVisible = false

        RowLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 18

            // --- Nav pane ---
            ColumnLayout {
                Layout.preferredWidth: 250
                Layout.minimumWidth: 250
                Layout.maximumWidth: 250
                Layout.fillHeight: true
                spacing: 8

                Text {
                    text: "Settings"; color: Config.fg; font.family: Config.textFont
                    font.pixelSize: 22; font.bold: true
                    Layout.bottomMargin: 2; Layout.leftMargin: 6
                }

                // Filter — the page list is long enough that scanning it beats scrolling it.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 19
                    color: Config.container
                    Behavior on color { ColorAnim {} }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 10
                        spacing: 8
                        MatIcon { text: "search"; color: Config.dim; font.pixelSize: 18 }
                        TextInput {
                            id: filterInput
                            Layout.fillWidth: true
                            text: win.filter
                            onTextChanged: win.filter = text
                            color: Config.fg
                            font.family: Config.textFont
                            font.pixelSize: 13
                            selectByMouse: true
                            selectionColor: Config.accent
                            selectedTextColor: Config.accentText
                            clip: true
                            Keys.onEscapePressed: {
                                if (filterInput.text.length > 0) filterInput.text = "";
                                else Shell.settingsVisible = false;
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: filterInput.text.length === 0
                                text: "Search settings"
                                color: Config.dim
                                font.family: Config.textFont
                                font.pixelSize: 13
                            }
                        }
                        IconBtn {
                            visible: filterInput.text.length > 0
                            icon: "close"; iconSize: 16
                            onClicked: filterInput.text = ""
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: navCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: navCol
                        width: parent.width
                        spacing: 3

                        Repeater {
                            model: win.navModel
                            delegate: ColumnLayout {
                                id: navEntry
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 3

                                readonly property bool current: win.page === navEntry.modelData.idx

                                SectionHeader {
                                    visible: navEntry.modelData.catStart
                                    first: navEntry.modelData.idx === 0
                                    text: navEntry.modelData.p.category
                                }

                                Rectangle {
                                    id: navPill
                                    Layout.fillWidth: true
                                    implicitHeight: 52
                                    radius: navEntry.current ? 22 : 14
                                    Behavior on radius { Spatial {} }
                                    color: navEntry.current ? Config.accentContainer : "transparent"
                                    Behavior on color { ColorAnim {} }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12; anchors.rightMargin: 12
                                        spacing: 12
                                        Rectangle {
                                            implicitWidth: 34; implicitHeight: 34; radius: 17
                                            color: navEntry.current ? Config.accent : Config.container
                                            Behavior on color { ColorAnim {} }
                                            MatIcon {
                                                anchors.centerIn: parent
                                                text: navEntry.modelData.p.icon
                                                font.pixelSize: 18
                                                color: navEntry.current ? Config.accentText : Config.fg
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Text {
                                                text: navEntry.modelData.p.label
                                                color: Config.fg
                                                font.family: Config.textFont; font.pixelSize: 13
                                                font.bold: navEntry.current
                                                Layout.fillWidth: true; elide: Text.ElideRight
                                            }
                                            Text {
                                                text: navEntry.modelData.p.desc
                                                color: Config.dim
                                                font.family: Config.textFont; font.pixelSize: 11
                                                Layout.fillWidth: true; elide: Text.ElideRight
                                            }
                                        }
                                    }
                                    // Follows the pill, which grows rounder once selected — a fixed
                                    // radius here made hover a different shape than the selection.
                                    StateLayer { ovRadius: navPill.radius; onTapped: win.page = navEntry.modelData.idx }
                                }
                            }
                        }

                        // Nothing matched the filter.
                        Text {
                            visible: win.navModel.length === 0
                            Layout.fillWidth: true
                            Layout.topMargin: 20
                            horizontalAlignment: Text.AlignHCenter
                            text: "No settings match “" + win.filter + "”"
                            color: Config.dim
                            font.family: Config.textFont; font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // --- Page host ---
            // Only the current page is instantiated; switching destroys the old one and its
            // pollers, which is also why sub-page stacks reset.
            Item {
                id: pageHost
                Layout.fillWidth: true
                Layout.minimumWidth: 1
                Layout.fillHeight: true

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    sourceComponent: win.pageComps[win.page] ?? null
                }

                // Fade + a small slide-up of the new page's content on switch.
                transform: Translate { id: pageSlide }
                Connections {
                    target: win
                    function onPageChanged() { pageAnim.restart(); }
                }
                ParallelAnimation {
                    id: pageAnim
                    NumberAnimation { target: pageHost; property: "opacity"; from: 0; to: 1
                                      duration: Motion.effectDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectCurve }
                    NumberAnimation { target: pageSlide; property: "y"; from: 10; to: 0
                                      duration: Motion.spatialDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve }
                }
            }
        }
    }
}
