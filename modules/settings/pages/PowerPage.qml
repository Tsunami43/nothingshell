// Power & lock: what idling does, plus the session actions that otherwise only exist in the
// bar's power popout.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
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
                    first: false; last: false
                    icon: "power"; label: "State"
                    value: Bat.charging ? "Charging" : (Bat.onBattery ? "Discharging" : "On mains")
                }
                ToggleRow {
                    first: false; last: true
                    text: "Battery saver"
                    // Names what it gives up, so nobody has to read services/Power.qml to find out.
                    subtext: Power.saving
                        ? "Active — live wallpaper, window previews, frame shader and background polling are off"
                        : "While on battery: pause the live wallpaper and window previews, flatten the frame, shorten animations and stop background polling"
                    checked: Config.batterySaver
                    onToggled: Config.batterySaver = !Config.batterySaver
                }
            }

            SectionHeader { text: "Session" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                // Every verb services/Session.qml offers; the bar shows a subset of the same list.
                Repeater {
                    model: Session.actions
                    ButtonRow {
                        required property var modelData
                        required property int index
                        first: index === 0
                        last: index === Session.actions.length - 1
                        icon: modelData.icon
                        label: modelData.label
                        destructive: modelData.destructive
                        // Locking leaves the shell running, so the window has to get out of the way.
                        onClicked: {
                            if (modelData.id === "lock") Shell.settingsVisible = false;
                            modelData.run();
                        }
                    }
                }
            }
        }
    }
}
