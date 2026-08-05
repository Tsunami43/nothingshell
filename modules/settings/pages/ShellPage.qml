// Shell: the surfaces the shell itself draws — the vertical bar, the top dashboard and the
// launcher. Everything here was previously a code edit away.
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
            title: "Shell"

            SectionHeader { first: true; text: "Surfaces" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                NavRow {
                    first: true; last: false
                    icon: "dock_to_left"; label: "Bar"
                    status: {
                        const on = [Config.barWorkspaces, Config.barWindow, Config.barTray, Config.barClock,
                                    Config.barVolume, Config.barBrightness, Config.barKeyboard,
                                    Config.barBattery, Config.barControls].filter(Boolean).length;
                        return on + " of 9 modules shown";
                    }
                    onClicked: stack.push(barPage)
                }
                NavRow {
                    first: false; last: false
                    icon: "dashboard"; label: "Dashboard"
                    status: ["Dashboard", "Performance", "Notifications"][Config.dashTab] ?? "Dashboard"
                    onClicked: stack.push(dashPage)
                }
                NavRow {
                    first: false; last: true
                    icon: "search"; label: "Launcher"
                    status: Config.launcherMax + " results max"
                    onClicked: stack.push(launcherPage)
                }
            }

            SectionHeader { text: "Motion" }
            SliderRow {
                first: true; last: true
                icon: "speed"
                label: "Animation speed"
                value: (2.0 - Config.motionScale) / 1.75
                valueText: Config.motionScale === 1 ? "Normal" : (1 / Config.motionScale).toFixed(2) + "×"
                onMoved: v => Config.motionScale = Math.round((2.0 - v * 1.75) * 20) / 20
            }
        }
    }

    // --- Bar ---
    Component {
        id: barPage
        PageBase {
            title: "Bar"
            isSubPage: true
            onBack: stack.pop()

            SectionHeader { first: true; text: "Modules" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ToggleRow {
                    first: true; last: false
                    text: "Workspaces"; checked: Config.barWorkspaces
                    onToggled: Config.barWorkspaces = !Config.barWorkspaces
                }
                ToggleRow {
                    first: false; last: false
                    text: "Active window"; subtext: "Icon and vertical title of the focused window"
                    checked: Config.barWindow
                    onToggled: Config.barWindow = !Config.barWindow
                }
                ToggleRow {
                    first: false; last: false
                    text: "System tray"; checked: Config.barTray
                    onToggled: Config.barTray = !Config.barTray
                }
                ToggleRow {
                    first: false; last: false
                    text: "Clock"; checked: Config.barClock
                    onToggled: Config.barClock = !Config.barClock
                }
                ToggleRow {
                    first: false; last: false
                    text: "Volume"; checked: Config.barVolume
                    onToggled: Config.barVolume = !Config.barVolume
                }
                ToggleRow {
                    first: false; last: false
                    text: "Brightness"
                    subtext: Brightness.available ? "" : "No DDC/CI monitor detected — hidden anyway"
                    checked: Config.barBrightness
                    onToggled: Config.barBrightness = !Config.barBrightness
                }
                ToggleRow {
                    first: false; last: false
                    text: "Keyboard layout"; checked: Config.barKeyboard
                    onToggled: Config.barKeyboard = !Config.barKeyboard
                }
                ToggleRow {
                    first: false; last: false
                    text: "Battery"
                    subtext: Bat.has ? "" : "No laptop battery — hidden anyway"
                    checked: Config.barBattery
                    onToggled: Config.barBattery = !Config.barBattery
                }
                ToggleRow {
                    first: false; last: true
                    text: "Network, Bluetooth, VPN"; subtext: "The controls pill above the power button"
                    checked: Config.barControls
                    onToggled: Config.barControls = !Config.barControls
                }
            }

            SectionHeader { text: "Clock" }
            SelectRow {
                first: true; last: true
                label: "Time format"
                options: [
                    { value: false, label: "24-hour" },
                    { value: true, label: "12-hour", subtext: "adds AM/PM" }
                ]
                value: Config.barClock12h
                onSelected: v => Config.barClock12h = v
            }
        }
    }

    // --- Dashboard ---
    Component {
        id: dashPage
        PageBase {
            title: "Dashboard"
            isSubPage: true
            onBack: stack.pop()

            SectionHeader { first: true; text: "Behaviour" }
            SelectRow {
                first: true; last: true
                label: "Open on"
                subtext: "The tab the dashboard resets to when it closes"
                options: [
                    { value: 0, label: "Dashboard" },
                    { value: 1, label: "Performance" },
                    { value: 2, label: "Notifications" }
                ]
                value: Config.dashTab
                onSelected: v => Config.dashTab = v
            }
        }
    }

    // --- Launcher ---
    Component {
        id: launcherPage
        PageBase {
            title: "Launcher"
            isSubPage: true
            onBack: stack.pop()

            SectionHeader { first: true; text: "Results" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                StepperRow {
                    first: true; last: false
                    label: "Maximum results"
                    value: Config.launcherMax
                    ladder: [10, 15, 20, 30, 50, 80, 120]
                    onChanged: v => Config.launcherMax = v
                }
                TextRow {
                    first: false; last: true
                    label: "Web search"
                    subtext: "Used when nothing matches; the query is appended URL-encoded"
                    value: Config.launcherSearchUrl
                    placeholder: "https://duckduckgo.com/?q="
                    onEdited: t => Config.launcherSearchUrl = t
                }
            }

            SectionHeader { text: "Commands" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ToggleRow {
                    first: true; last: false
                    text: "Session commands"
                    subtext: "Offer Log out, Suspend, Reboot and Shut down under “>”"
                    checked: Config.launcherDangerous
                    onToggled: Config.launcherDangerous = !Config.launcherDangerous
                }
                InfoRow {
                    first: false; last: true
                    icon: "keyboard"; label: "Available commands"
                    value: Actions.list.length + ""
                }
            }

            SectionHeader { text: "Clipboard history" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ToggleRow {
                    first: true; last: false
                    text: "Remember what is copied"
                    subtext: "Kept in memory for the session only — never written to disk"
                    checked: Config.clipboardEnabled
                    onToggled: Config.clipboardEnabled = !Config.clipboardEnabled
                }
                StepperRow {
                    first: false; last: false
                    visible: Config.clipboardEnabled
                    label: "Entries kept"
                    value: Config.clipboardMax
                    ladder: [20, 50, 100, 200, 500]
                    onChanged: v => Config.clipboardMax = v
                }
                ButtonRow {
                    first: false; last: true
                    icon: "content_paste_off"
                    label: "Clear history now"
                    subtext: Clip.entries.length === 0
                             ? "Nothing stored"
                             : Clip.entries.length + " entries · " + Math.max(1, Math.round(Clip.usedBytes / 1024)) + " KB"
                    destructive: Clip.entries.length > 0
                    onClicked: Clip.clear()
                }
            }

            SectionHeader { text: "Prefixes" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                InfoRow { first: true; last: false; icon: "chevron_right"; label: "Commands"; value: ">" }
                InfoRow { first: false; last: false; icon: "content_paste"; label: "Clipboard history"; value: "#" }
                InfoRow { first: false; last: false; icon: "calculate"; label: "Calculator"; value: "= (or bare arithmetic)" }
                InfoRow { first: false; last: false; icon: "terminal"; label: "Run a command"; value: "$" }
                InfoRow { first: false; last: true; icon: "mood"; label: "Emoji"; value: ":" }
            }
        }
    }
}
