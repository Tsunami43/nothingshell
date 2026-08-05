// Capture defaults — the same knobs the capture panel exposes mid-flight, in a place where they
// can be set once and forgotten. The panel writes the very same Config keys, so changing a value
// in either place is immediately reflected in the other.
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

    Component {
        id: mainPage
        PageBase {
            title: "Capture"

            SectionHeader { first: true; text: "Screenshots" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                SelectRow {
                    first: true; last: false
                    label: "Default source"
                    options: [
                        { value: "region", label: "Region", subtext: "slurp picker" },
                        { value: "screen", label: "Whole screen" }
                    ]
                    value: Config.capSource
                    onSelected: v => Config.capSource = v
                }
                ToggleRow {
                    first: false; last: false
                    text: "Copy to clipboard"
                    checked: Config.shotCopy
                    onToggled: Config.shotCopy = !Config.shotCopy
                }
                ToggleRow {
                    first: false; last: false
                    text: "Save a file"
                    subtext: Config.shotSave ? "" : "Off — screenshots go to the clipboard only"
                    checked: Config.shotSave
                    onToggled: Config.shotSave = !Config.shotSave
                }
                ToggleRow {
                    first: false; last: false
                    text: "Include the cursor"
                    checked: Config.shotCursor
                    onToggled: Config.shotCursor = !Config.shotCursor
                }
                TextRow {
                    first: false; last: true
                    visible: Config.shotSave
                    label: "Save to"
                    subtext: "A leading / is the filesystem root; anything else is under your home"
                    value: Config.shotDir
                    placeholder: Capture.niceDir(Capture.shotTarget)
                    onEdited: t => Config.shotDir = Capture.niceDir(t)
                }
            }

            SectionHeader { text: "Recording" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                SelectRow {
                    first: true; last: false
                    label: "Container"
                    subtext: "Matroska survives a crash mid-recording; mp4 does not"
                    options: [
                        { value: "mkv", label: "MKV", subtext: "Recommended" },
                        { value: "mp4", label: "MP4" },
                        { value: "webm", label: "WebM" }
                    ]
                    value: Config.recFormat
                    onSelected: v => Config.recFormat = v
                }
                SelectRow {
                    first: false; last: false
                    label: "Quality"
                    options: [
                        { value: "medium", label: "Medium" },
                        { value: "high", label: "High" },
                        { value: "very_high", label: "Very high" },
                        { value: "ultra", label: "Ultra" }
                    ]
                    value: Config.recQuality
                    onSelected: v => Config.recQuality = v
                }
                SelectRow {
                    first: false; last: false
                    label: "Frame rate"
                    options: [
                        { value: 30, label: "30 fps" },
                        { value: 60, label: "60 fps" },
                        { value: 120, label: "120 fps" },
                        { value: 144, label: "144 fps" }
                    ]
                    value: Config.recFps
                    onSelected: v => Config.recFps = v
                }
                SelectRow {
                    first: false; last: false
                    label: "Audio"
                    options: [
                        { value: "none", label: "None" },
                        { value: "desktop", label: "Desktop" },
                        { value: "mic", label: "Microphone" },
                        { value: "both", label: "Desktop + microphone" }
                    ]
                    value: Config.recAudio
                    onSelected: v => Config.recAudio = v
                }
                ToggleRow {
                    first: false; last: false
                    text: "Include the cursor"
                    checked: Config.recCursor
                    onToggled: Config.recCursor = !Config.recCursor
                }
                ToggleRow {
                    first: false; last: false
                    text: "Copy the file path when it stops"
                    checked: Config.recCopyPath
                    onToggled: Config.recCopyPath = !Config.recCopyPath
                }
                TextRow {
                    first: false; last: true
                    label: "Save to"
                    subtext: "A leading / is the filesystem root; anything else is under your home"
                    value: Config.recDir
                    placeholder: Capture.niceDir(Capture.recTarget)
                    onEdited: t => Config.recDir = Capture.niceDir(t)
                }
            }

            SectionHeader { text: "Now" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                InfoRow {
                    first: true; last: false
                    icon: "videocam"; label: "Recorder"
                    value: Capture.active ? (Capture.paused ? "Paused — " + Capture.elapsedText
                                                            : "Recording — " + Capture.elapsedText)
                                          : "Idle"
                }
                InfoRow {
                    first: false; last: Capture.lastFile === ""
                    icon: "tune"; label: "Current settings"; value: Capture.recSummary
                }
                ButtonRow {
                    first: false; last: true
                    visible: Capture.lastFile !== ""
                    icon: "content_copy"
                    label: "Copy last file path"
                    subtext: Capture.lastFile
                    onClicked: Quickshell.execDetached(["wl-copy", Capture.lastFile])
                }
            }
        }
    }
}
