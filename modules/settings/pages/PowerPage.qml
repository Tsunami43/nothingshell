// Power & lock: what idling does, plus the session actions that otherwise only exist in the
// bar's power popout.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs
import qs.services
import qs.components
import qs.modules.settings.common
StackView {
    id: stack
    clip: true
    initialItem: mainPage

    // "5 min" reads better than "300", and the steps people actually want are not linear.
    function durationText(s) {
        if (s <= 0) return "Never";
        if (s < 60) return s + " s";
        if (s % 60 === 0) return (s / 60) + " min";
        return Math.floor(s / 60) + " min " + (s % 60) + " s";
    }
    // Snap to a sensible ladder instead of stepping one second at a time. "Never" (0) is only
    // offered where switching the behaviour off entirely makes sense.
    readonly property var lockLadder: [30, 60, 120, 300, 600, 900, 1800, 3600]
    readonly property var dpmsLadder: [0, 60, 120, 300, 600, 900, 1800, 3600]

    Component {
        id: mainPage
        PageBase {
            title: "Power & lock"

            SectionHeader { first: true; text: "Idle" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ToggleRow {
                    first: true; last: false
                    text: "Auto-lock"
                    subtext: "Lock the screen after a period of inactivity"
                    checked: Config.autoLock
                    onToggled: Config.autoLock = !Config.autoLock
                }
                StepperRow {
                    first: false; last: false
                    visible: Config.autoLock
                    label: "Lock after"
                    value: Config.autoLockTimeout
                    ladder: stack.lockLadder
                    valueText: stack.durationText(Config.autoLockTimeout)
                    onChanged: v => Config.autoLockTimeout = v
                }
                StepperRow {
                    first: false; last: false
                    label: "Turn displays off after"
                    subtext: "Independent of the lock — screens may sleep before or after it"
                    value: Config.dpmsTimeout
                    ladder: stack.dpmsLadder
                    valueText: stack.durationText(Config.dpmsTimeout)
                    onChanged: v => Config.dpmsTimeout = v
                }
                ToggleRow {
                    first: false; last: false
                    text: "Keep awake"
                    subtext: "Inhibit idling entirely until turned off"
                    checked: Shell.keepAwake
                    onToggled: Shell.keepAwake = !Shell.keepAwake
                }
                ToggleRow {
                    first: false; last: true
                    text: "Game mode"
                    subtext: "Drop animations, blur and rounding; suppresses notifications and idle"
                    checked: GameMode.enabled
                    onToggled: GameMode.toggle()
                }
            }

            SectionHeader { visible: Bat.has; text: "Battery" }
            ColumnLayout {
                Layout.fillWidth: true
                visible: Bat.has
                spacing: 3
                InfoRow {
                    first: true; last: false
                    icon: Bat.charging ? "battery_charging_full" : "battery_full"
                    label: "Charge"; value: Bat.percent + "%"
                }
                InfoRow {
                    first: false; last: true
                    icon: "power"; label: "State"; value: Bat.charging ? "Charging" : "Discharging"
                }
            }

            SectionHeader { text: "Session" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ButtonRow {
                    first: true; last: false
                    icon: "lock"; label: "Lock now"
                    onClicked: { Shell.settingsVisible = false; Lock.locked = true; }
                }
                ButtonRow {
                    first: false; last: false
                    icon: "logout"; label: "Log out"; destructive: true
                    onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
                }
                ButtonRow {
                    first: false; last: false
                    icon: "bedtime"; label: "Suspend"; destructive: true
                    onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                }
                ButtonRow {
                    first: false; last: false
                    icon: "restart_alt"; label: "Reboot"; destructive: true
                    onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                }
                ButtonRow {
                    first: false; last: true
                    icon: "power_settings_new"; label: "Shut down"; destructive: true
                    onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                }
            }
        }
    }
}
