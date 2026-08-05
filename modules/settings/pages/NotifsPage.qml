// Notifications: when a toast is allowed to appear, how long it stays, and which apps never
// get one. Nothing here stops a notification being *tracked* — the dashboard's list always
// receives everything; these rules only govern the transient popup.
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

    Component {
        id: mainPage
        PageBase {
            title: "Notifications"

            SectionHeader { first: true; text: "Do not disturb" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ToggleRow {
                    first: true; last: false
                    text: "Do not disturb"
                    subtext: "Silence every toast; the dashboard list keeps filling"
                    checked: Config.dnd
                    onToggled: Config.dnd = !Config.dnd
                }
                ToggleRow {
                    first: false; last: false
                    text: "Silence in fullscreen"
                    subtext: "While a fullscreen window has focus"
                    checked: Config.notifSuppressFullscreen
                    onToggled: Config.notifSuppressFullscreen = !Config.notifSuppressFullscreen
                }
                ToggleRow {
                    first: false; last: true
                    text: "Silence in game mode"
                    checked: Config.notifSuppressGame
                    onToggled: Config.notifSuppressGame = !Config.notifSuppressGame
                }
            }

            SectionHeader { text: "Toasts" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                StepperRow {
                    first: true; last: false
                    label: "Dismiss after"
                    subtext: "Critical notifications linger 60% longer"
                    value: Config.notifTimeout
                    ladder: [2000, 3000, 5000, 8000, 12000, 20000, 30000]
                    valueText: (Config.notifTimeout / 1000).toFixed(Config.notifTimeout % 1000 ? 1 : 0) + " s"
                    onChanged: v => Config.notifTimeout = v
                }
                InfoRow {
                    first: false; last: true
                    icon: "info"; label: "Shown at once"; value: "1"
                }
            }

            SectionHeader { text: "Apps" }
            NavRow {
                first: true; last: true
                icon: "apps"
                label: "Per-app toasts"
                status: {
                    const n = (Config.notifMuted ?? []).length;
                    return n === 0 ? "Nothing muted" : n === 1 ? "1 app muted" : n + " apps muted";
                }
                onClicked: stack.push(appsPage)
            }
        }
    }

    Component {
        id: appsPage
        PageBase {
            title: "Per-app toasts"
            isSubPage: true
            onBack: stack.pop()

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: "Apps that have sent a notification since the shell started. Muting one hides "
                      + "its toasts; its notifications still reach the dashboard."
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            ItemList {
                Layout.fillHeight: true
                placeholderIcon: "notifications_off"
                placeholderText: "No app has sent a notification yet"
                model: Notifs.apps
                delegate: Item {
                    id: appRow
                    required property string modelData
                    readonly property bool muted: Notifs.muted(appRow.modelData)
                    width: ListView.view.width
                    implicitHeight: 50
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 16
                        spacing: 12
                        Text {
                            text: appRow.modelData
                            color: appRow.muted ? Config.dim : Config.fg
                            font.family: Config.textFont; font.pixelSize: 13
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        MatIcon {
                            text: appRow.muted ? "notifications_off" : "notifications"
                            color: appRow.muted ? Config.dim : Config.accent
                            font.pixelSize: 18
                        }
                    }
                    StateLayer {
                        ovRadius: 8
                        onTapped: Notifs.setMuted(appRow.modelData, !appRow.muted)
                    }
                }
            }
        }
    }
}
