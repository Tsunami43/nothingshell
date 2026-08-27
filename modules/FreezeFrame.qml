// The still held over the desktop while slurp picks a region; services/Capture.qml takes the frame
// and crops the pick out of it.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: freeze
    required property var modelData
    screen: modelData

    // Only the output the still came from; the others keep showing the live desktop.
    visible: Capture.freezeShown && Capture.freezePath !== ""
             && (Capture.freezeMon?.name ?? "") === modelData.name
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // The pointer belongs to slurp, which maps above this.
    mask: Region {}

    Image {
        anchors.fill: parent
        // Monitor pixels back over the same monitor: 1:1 at any scale.
        fillMode: Image.Stretch
        smooth: false
        cache: false          // a fresh path per capture, so nothing stale can be handed back
        source: freeze.visible ? "file://" + Capture.freezePath : ""
    }
}
