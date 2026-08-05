// Top-right transient notification popup, one at a time (the full list lives in the dashboard).
// The card has no background of its own: it reports its rect to PopoutState.box2 and the Frame
// bulges the TOP border down into it, so the toast flows out of the frame with no seam. Content
// fades, the bulge grows and shrinks in place. Swipe or click to dismiss.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: toastWin
    required property var modelData
    screen: modelData
    anchors { top: true; right: true }
    margins { top: 16; right: 16 }
    implicitWidth: 340
    implicitHeight: Math.max(1, toastList.contentHeight)   // never animated — instant map/unmap only
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay

    // Map from the model count (a ListView inside an unmapped window never lays out its delegates).
    visible: Notifs.toasts.count > 0

    // Report the toast body to the Frame's second bulge slot in screen px: from the top border
    // (y = 0) down past the card, spanning its band at the top-right. The single source of truth
    // for that bulge — driven by the model count and list height, NOT per-delegate, which raced on
    // rapid toasts and left the frame deformed with no toast on screen.
    function syncBulge() {
        // Anchored to its own top-right corner, so the bulge grows out of and retracts into it.
        // The Frame animates SIZE only, so the default top-left anchor sent the toast towards the
        // opposite corner from the one it lives in.
        if (Notifs.toasts.count > 0 && toastList.contentHeight > 1)
            PopoutState.setBox2(toastWin.screen.width - toastWin.margins.right - toastWin.implicitWidth,
                                0, toastWin.implicitWidth, toastWin.margins.top + toastList.contentHeight,
                                1.0, 0.0);
        else
            PopoutState.clear2();
    }
    Connections { target: Notifs.toasts; function onCountChanged() { toastWin.syncBulge(); } }

    ListView {
        id: toastList
        anchors.fill: parent
        model: Notifs.toasts
        interactive: false
        cacheBuffer: 4000
        onContentHeightChanged: toastWin.syncBulge()

        // Enter/exit: fade the content; the bulge (Frame) grows/shrinks to match.
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1
                              duration: Motion.effectDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectCurve }
        }

        delegate: Item {
            id: wrapper
            required property int index
            required property int key
            required property string summary
            required property string body
            required property string appName
            required property string image
            required property int urgency
            required property var notif
            readonly property bool critical: urgency === 2
            // Named actions only — the "default" action is "activate the app", handled by clicking
            // the toast body, not shown as a (label-less) button.
            readonly property var buttonActions: (notif?.actions ?? []).filter(a => a.identifier !== "default")

            width: toastList.width
            implicitHeight: card.implicitHeight

            // Exit: fade the content out; the bulge is cleared by syncBulge when the model empties.
            ListView.onRemove: removeAnim.start()
            SequentialAnimation {
                id: removeAnim
                PropertyAction { target: wrapper; property: "ListView.delayRemove"; value: true }
                PropertyAction { target: wrapper; property: "enabled"; value: false }
                NumberAnimation {
                    target: wrapper; property: "opacity"; to: 0
                    duration: Motion.effectDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectCurve
                }
                PropertyAction { target: wrapper; property: "ListView.delayRemove"; value: false }
            }

            Rectangle {
                id: card
                width: wrapper.width
                implicitHeight: trow.implicitHeight + 24
                radius: 14
                color: "transparent"                      // background is the Frame bulge (box2)

                // Swipe-to-dismiss: follow the finger, fade with distance, release past a threshold.
                property real dragX: 0
                x: dragX
                opacity: 1 - Math.min(0.9, Math.abs(dragX) / width)
                Behavior on dragX { enabled: !toastMa.pressed; Effect {} }

                Row {
                    id: trow
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; rightMargin: 32 }
                    spacing: 10

                    // Always present: a notification with no art of its own gets its glyph, so the
                    // text starts at the same place whatever sent it.
                    Rectangle {
                        width: 44; height: 44; radius: 10; clip: true
                        color: Config.container
                        Image {
                            id: toastArt
                            anchors.fill: parent
                            source: Notifs.art(wrapper.notif)
                            sourceSize: Qt.size(44, 44)
                            // A screenshot is a wide still and wants cropping; an app icon is
                            // square and must not be blown past its own edges.
                            fillMode: wrapper.image.length > 0 ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }
                        MatIcon {
                            anchors.centerIn: parent
                            visible: !toastArt.visible
                            text: Notifs.glyph(wrapper.appName, wrapper.summary)
                            font.pixelSize: 22
                            color: wrapper.critical ? Config.error : Config.accent
                        }
                    }
                    Column {
                        width: parent.width - 54
                        spacing: 3
                        // PlainText everywhere a notification's own strings are drawn: the default
                        // AutoText hands anything Qt::mightBeRichText() likes to the rich-text
                        // engine, which resolves <img src="http://…"> over the network. A
                        // notification body is routinely a chat message written by a stranger, so
                        // that is a tracking pixel one message away.
                        Text {
                            visible: wrapper.appName.length > 0
                            text: wrapper.appName
                            textFormat: Text.PlainText
                            color: wrapper.critical ? Config.error : Config.accent
                            font.family: Config.textFont; font.pixelSize: 10; font.bold: true
                        }
                        Text {
                            text: wrapper.summary
                            textFormat: Text.PlainText
                            color: Config.fg; font.family: Config.textFont; font.pixelSize: 14; font.bold: true
                            width: parent.width; elide: Text.ElideRight
                        }
                        Text {
                            visible: wrapper.body.length > 0
                            // Markdown is what the freedesktop spec's markup amounts to in practice,
                            // so it stays — but images are stripped first (![alt](url) fetches the
                            // url exactly like the HTML case above) and only the inline styling is
                            // left. Bodies with no markup at all skip the parser entirely.
                            text: Notifs.safeBody(wrapper.body)
                            textFormat: /[*_`~\[]/.test(wrapper.body) ? Text.MarkdownText : Text.PlainText
                            color: Config.dim; font.family: Config.textFont; font.pixelSize: 12
                            width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight
                            // Only what a browser would take. A markdown link can name any scheme,
                            // and xdg-open would hand file:// or a registered custom scheme straight
                            // to whichever application claims it.
                            onLinkActivated: url => {
                                if (/^https?:\/\//i.test(url)) Quickshell.execDetached(["xdg-open", url]);
                            }
                        }
                        Row {
                            visible: wrapper.buttonActions.length > 0
                            topPadding: 6
                            spacing: 6
                            Repeater {
                                model: wrapper.buttonActions
                                Rectangle {
                                    id: actBtn
                                    required property var modelData
                                    implicitWidth: actText.implicitWidth + 20; implicitHeight: 26; radius: 8
                                    color: Config.container
                                    Text {
                                        id: actText
                                        anchors.centerIn: parent
                                        text: actBtn.modelData.text
                                        textFormat: Text.PlainText
                                        color: Config.fg; font.family: Config.textFont; font.pixelSize: 11
                                    }
                                    StateLayer { ovRadius: 8; onTapped: { actBtn.modelData.invoke(); Notifs.removeToast(wrapper.key); } }
                                }
                            }
                        }
                    }
                }

                // Auto-dismiss (paused while hovered; critical notifications linger 60% longer).
                Timer {
                    interval: wrapper.critical ? Math.round(Config.notifTimeout * 1.6) : Config.notifTimeout
                    running: !toastMa.containsMouse
                    onTriggered: Notifs.removeToast(wrapper.key)
                }
                MouseArea {
                    id: toastMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    property real startX: 0
                    onPressed: e => startX = e.x
                    onPositionChanged: e => { if (pressed) card.dragX = e.x - startX; }
                    onReleased: {
                        if (Math.abs(card.dragX) > card.width * 0.33) Notifs.removeToast(wrapper.key);
                        card.dragX = 0;
                    }
                    onClicked: {
                        if (Math.abs(card.dragX) >= 5) return;   // was a swipe
                        // Switch to the sending window: the sender-pid hint walked up to the owning
                        // Hyprland window, which works for a CLI app inside a terminal too
                        // (focus_on_activate can't — the app never requests it).
                        const pid = wrapper.notif?.hints?.["sender-pid"];
                        if (pid) Quickshell.execDetached([Paths.focusSenderScript, String(pid)]);
                        const def = (wrapper.notif?.actions ?? []).find(a => a.identifier === "default");
                        if (def) def.invoke();
                        Notifs.removeToast(wrapper.key);
                    }
                }

                // Close button (top-right) — added last so it sits above the card's click area.
                MatIcon {
                    anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 10 }
                    text: "close"
                    font.pixelSize: 16
                    color: closeMa.containsMouse ? Config.fg : Config.dim
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.removeToast(wrapper.key)
                    }
                }
            }
        }
    }
}
