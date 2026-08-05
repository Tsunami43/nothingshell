// Fullscreen wallpaper layer. Two ping-ponging images cross-fade on wallpaper change.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Background
    color: Config.bg

    Item {
        id: wallHost
        anchors.fill: parent
        // `current` tracks Config; a/b are the two layers (not bound, so we can flip them).
        property string current: Config.wallpaper
        property string a: Config.wallpaper
        property string b: ""
        property bool front: true   // true = image 'a' is on top
        Image {
            anchors.fill: parent; source: wallHost.a
            fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
            opacity: wallHost.front ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
        }
        Image {
            anchors.fill: parent; source: wallHost.b
            fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
            opacity: wallHost.front ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
        }
        // Load the new wallpaper into the hidden layer, then flip to cross-fade.
        onCurrentChanged: {
            if (wallHost.front) wallHost.b = wallHost.current;
            else wallHost.a = wallHost.current;
            wallHost.front = !wallHost.front;
        }
    }

    // Live video wallpaper (over the still image; only when a video is configured).
    // Paused whenever nothing can see it: a full-screen window covers the desktop outright, and
    // the lock screen draws its own copy on top. Decoding either case is pure waste.
    VideoWall {
        anchors.fill: parent
        visible: Config.videoWallpaper.length > 0
        active: !Hypr.fullscreenActive && !Lock.locked
        file: Config.videoWallpaper
    }

    // Large clock on the desktop (visible where no window covers it).
    DesktopClock {
        anchors.left: parent.left; anchors.top: parent.top
        anchors.leftMargin: 96; anchors.topMargin: 72
    }
}
