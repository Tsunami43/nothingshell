// Language & input: the system locale and time zone (read-only — both are privileged), and the
// Hyprland keyboard layout list, which is ours to edit.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.components
import qs.modules.settings.common
StackView {
    id: stack
    clip: true
    initialItem: mainPage

    Component.onCompleted: { Input.active = true; SysLocale.active = true; }
    Component.onDestruction: { Input.active = false; SysLocale.active = false; }

    // Common xkb switcher options, so the usual choice is one tap rather than a string to recall.
    readonly property var switchers: [
        { value: "custom:caps_group_nocaps", label: "Caps Lock", subtext: "custom xkb symbol" },
        { value: "grp:caps_toggle", label: "Caps Lock", subtext: "grp:caps_toggle" },
        { value: "grp:alt_shift_toggle", label: "Alt + Shift" },
        { value: "grp:ctrl_shift_toggle", label: "Ctrl + Shift" },
        { value: "grp:win_space_toggle", label: "Super + Space" },
        { value: "grp:alt_space_toggle", label: "Alt + Space" },
        { value: "", label: "None" }
    ]

    Component {
        id: mainPage
        PageBase {
            title: "Language & input"

            SectionHeader { first: true; text: "Region" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                InfoRow {
                    first: true; last: false
                    icon: "globe"; label: "System language"
                    value: SysLocale.langName ? SysLocale.langName + " · " + SysLocale.lang : (SysLocale.lang || "—")
                }
                InfoRow {
                    first: false; last: false
                    icon: "schedule"; label: "Time zone"
                    value: SysLocale.timezone + (SysLocale.ntp ? " · NTP" : "")
                }
                NavRow {
                    first: false; last: false
                    icon: "translate"; label: "Change the system language"
                    status: "Needs root — copies the command"
                    onClicked: stack.push(localePage)
                }
                NavRow {
                    first: false; last: true
                    icon: "public"; label: "Change the time zone"
                    status: "Needs root — copies the command"
                    onClicked: stack.push(tzPage)
                }
            }

            SectionHeader { text: "Keyboard layouts" }
            ItemList {
                id: layoutList
                model: Input.layouts
                placeholderIcon: "keyboard"
                placeholderText: "No keyboard reported"
                delegate: Item {
                    id: lay
                    required property string modelData
                    required property int index
                    readonly property bool current: lay.index === Input.activeIndex
                    width: ListView.view.width
                    implicitHeight: 52
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 8
                        spacing: 10
                        MatIcon {
                            text: lay.current ? "keyboard" : "keyboard_alt"
                            color: lay.current ? Config.accent : Config.dim
                            font.pixelSize: 20
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: lay.modelData.toUpperCase()
                                      + ((Input.variants[lay.index] ?? "") ? " (" + Input.variants[lay.index] + ")" : "")
                                color: Config.fg; font.family: Config.textFont
                                font.pixelSize: 13; font.bold: lay.current
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                visible: lay.index === 0 || lay.current
                                text: lay.current ? (Input.activeKeymap || "Active") : "Default"
                                color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }
                        // Grouped in their own row: IconBtn carries Layout.alignment, which would
                        // otherwise let the parent RowLayout spread the three across the width.
                        RowLayout {
                            spacing: 2
                            IconBtn {
                                icon: "keyboard_arrow_up"; iconSize: 16
                                opacity: lay.index > 0 ? 1 : 0.3
                                onClicked: Input.moveLayout(lay.index, -1)
                            }
                            IconBtn {
                                icon: "keyboard_arrow_down"; iconSize: 16
                                opacity: lay.index < Input.layouts.length - 1 ? 1 : 0.3
                                onClicked: Input.moveLayout(lay.index, 1)
                            }
                            IconBtn {
                                icon: "close"; iconSize: 16
                                tint: Config.danger
                                opacity: Input.layouts.length > 1 ? 1 : 0.3
                                onClicked: Input.removeLayout(lay.index)
                            }
                        }
                    }
                    // The whole row switches to this layout; the buttons above take precedence.
                    StateLayer {
                        ovTopRadius: layoutList.rowTop(lay.index)
                        ovBottomRadius: layoutList.rowBottom(lay.index)
                        onTapped: Input.setLayout(lay.index)
                    }
                }
            }
            NavRow {
                first: true; last: true
                icon: "add"; label: "Add a layout"
                status: Input.catalog.length ? Input.catalog.length + " available" : "Loading…"
                onClicked: stack.push(addPage)
            }

            SectionHeader { text: "Behaviour" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                SelectRow {
                    first: true; last: false
                    label: "Switch layouts with"
                    subtext: Input.options || "No xkb options set"
                    options: stack.switchers
                    value: Input.options
                    onSelected: v => Input.setOptions(v)
                }
                ToggleRow {
                    first: false; last: false
                    text: "NumLock on start"
                    checked: Input.numlock
                    onToggled: Input.setNumlock(!Input.numlock)
                }
                ButtonRow {
                    first: false; last: true
                    icon: "swap_horiz"; label: "Switch to the next layout now"
                    onClicked: Input.next()
                }
            }

            SectionHeader { text: "Keyboards" }
            ItemList {
                model: Input.keyboards
                placeholderIcon: "keyboard_off"
                placeholderText: "No keyboards"
                delegate: Item {
                    id: kb
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: 46
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 16
                        spacing: 10
                        Text {
                            text: kb.modelData.name
                            textFormat: Text.PlainText   // a USB device descriptor picks this string
                            color: kb.modelData.main ? Config.fg : Config.dim
                            font.family: Config.textFont; font.pixelSize: 12
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        Text {
                            text: kb.modelData.main ? "Primary · " + kb.modelData.active_keymap
                                                    : kb.modelData.active_keymap
                            color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }

    // --- Add a layout ---
    Component {
        id: addPage
        PageBase {
            id: addP
            property string query: ""
            title: "Add a layout"
            isSubPage: true
            onBack: stack.pop()

            TextRow {
                first: true; last: true
                label: "Search"
                value: addP.query
                placeholder: "us, ru, de…"
                // Filter as you type; nothing is applied until a row is tapped.
                live: true
                onEdited: t => addP.query = t
            }

            ItemList {
                id: candList
                Layout.fillHeight: true
                placeholderIcon: "search_off"
                placeholderText: "No layout matches"
                model: {
                    const q = addP.query.trim().toLowerCase();
                    const all = Input.catalog.filter(c => Input.layouts.indexOf(c) < 0);
                    return (q ? all.filter(c => c.includes(q)) : all).slice(0, 200);
                }
                delegate: Item {
                    id: cand
                    required property string modelData
                    width: ListView.view.width
                    implicitHeight: 42
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: cand.modelData
                        color: Config.fg; font.family: Config.textFont; font.pixelSize: 13
                    }
                    StateLayer {
                        ovRadius: 8
                        onTapped: { Input.addLayout(cand.modelData); stack.pop(); }
                    }
                }
            }
        }
    }

    // --- Locale (read-only + copy) ---
    Component {
        id: localePage
        PageBase {
            id: locP
            property string query: ""
            title: "System language"
            isSubPage: true
            onBack: stack.pop()

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: "Changing the system locale is a privileged operation. Pick one below and the "
                      + "matching command is copied to the clipboard — run it in a terminal, then log "
                      + "out and back in."
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
            InfoRow { first: true; last: true; icon: "check"; label: "Current"; value: SysLocale.lang }

            // Same cap as the time zone list below it: a glibc install with every locale
            // generated runs to several hundred entries, and none of these lists virtualise.
            TextRow {
                first: true; last: true
                label: "Search"
                value: locP.query
                placeholder: "en_US, ru_RU, utf8…"
                live: true
                onEdited: t => locP.query = t
            }

            SectionHeader { text: "Available" }
            ItemList {
                id: localeList
                Layout.fillHeight: true
                placeholderIcon: "translate"
                placeholderText: SysLocale.localeCatalog.length === 0 ? "Loading locales…" : "No locale matches"
                model: {
                    const q = locP.query.trim().toLowerCase();
                    const all = q ? SysLocale.localeCatalog.filter(l => l.toLowerCase().includes(q))
                                  : SysLocale.localeCatalog;
                    return all.slice(0, 200);
                }
                delegate: Item {
                    id: loc
                    required property string modelData
                    required property int index
                    width: ListView.view.width
                    implicitHeight: 42
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 16
                        Text {
                            text: loc.modelData; color: Config.fg
                            font.family: Config.textFont; font.pixelSize: 13
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        MatIcon {
                            visible: loc.modelData === SysLocale.lang
                            text: "check"; color: Config.accent; font.pixelSize: 16
                        }
                    }
                    StateLayer {
                        ovTopRadius: localeList.rowTop(loc.index)
                        ovBottomRadius: localeList.rowBottom(loc.index)
                        onTapped: SysLocale.copyLocaleCommand(loc.modelData)
                    }
                }
            }
        }
    }

    // --- Time zone (read-only + copy) ---
    Component {
        id: tzPage
        PageBase {
            id: tzP
            property string query: ""
            title: "Time zone"
            isSubPage: true
            onBack: stack.pop()

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: "Tap a zone to copy the command that sets it. It needs root."
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
            InfoRow { first: true; last: true; icon: "check"; label: "Current"; value: SysLocale.timezone }

            // Search, and a cap on what is drawn. The list inside ItemList does not virtualise —
            // its height IS its content height, so every row exists at once — and there are ~600
            // zones on a normal install, each with its own state layer and mask. Opening the page
            // built all of them.
            TextRow {
                first: true; last: true
                label: "Search"
                value: tzP.query
                placeholder: "europe, moscow, utc…"
                live: true
                onEdited: t => tzP.query = t
            }

            SectionHeader { text: "Available" }
            ItemList {
                id: tzList
                Layout.fillHeight: true
                placeholderIcon: "public"
                placeholderText: SysLocale.timezones.length === 0 ? "Loading zones…" : "No zone matches"
                model: {
                    const q = tzP.query.trim().toLowerCase();
                    const all = q ? SysLocale.timezones.filter(z => z.toLowerCase().includes(q))
                                  : SysLocale.timezones;
                    return all.slice(0, 200);
                }
                delegate: Item {
                    id: tz
                    required property string modelData
                    required property int index
                    width: ListView.view.width
                    implicitHeight: 42
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 16
                        Text {
                            text: tz.modelData; color: Config.fg
                            font.family: Config.textFont; font.pixelSize: 13
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        MatIcon {
                            visible: tz.modelData === SysLocale.timezone
                            text: "check"; color: Config.accent; font.pixelSize: 16
                        }
                    }
                    StateLayer {
                        ovTopRadius: tzList.rowTop(tz.index)
                        ovBottomRadius: tzList.rowBottom(tz.index)
                        onTapped: SysLocale.copyTimezoneCommand(tz.modelData)
                    }
                }
            }
        }
    }
}
