// Tray menu popout: ours rather than native, because native menus don't hover-close.
// The anchor moves with the cursor and the D-Bus menu resizes late, hence widget/bulgeHeight.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

BarPopout {
    id: pop
    name: "traymenu"
    available: !!pop.bar.trayMenuAnchor && !!pop.bar.trayMenuHandle
    implicitWidth: 214
    bodyHeight: menuCol.implicitHeight + 24
    // Straight off the layout; under a pixel means mid-reload, which report() ignores.
    bulgeHeight: menuCol.implicitHeight + 24 + Config.popFillet * 2
    // Hovering another icon swaps the menu with no size change to react to.
    reportOnHover: true

    Connections {
        target: pop.bar
        function onTrayMenuAnchorChanged() { pop.report(false); }
    }

    QsMenuOpener {
        id: trayOpener
        menu: pop.bar.trayMenuHandle
    }

    ColumnLayout {
        id: menuCol
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 12 + Config.popFillet * 2 - pop.botPad; leftMargin: 8; rightMargin: 8 }
        spacing: 2
        // implicitHeight doesn't notify reliably; a refill would otherwise leave the bulge collapsed.
        onImplicitHeightChanged: pop.report(false)

        Repeater {
            model: trayOpener.children
            delegate: Item {
                id: menuItem
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: menuItem.modelData.isSeparator ? 9 : 32

                Rectangle {
                    visible: menuItem.modelData.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 8; anchors.rightMargin: 8
                    implicitHeight: 1; color: Config.outline
                }
                Rectangle {
                    visible: !menuItem.modelData.isSeparator
                    anchors.fill: parent
                    radius: 8
                    color: "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Image {
                            visible: (menuItem.modelData.icon ?? "") !== ""
                            Layout.preferredWidth: visible ? 16 : 0
                            Layout.preferredHeight: 16
                            sourceSize: Qt.size(16, 16)
                            source: menuItem.modelData.icon ?? ""
                        }
                        Text {
                            text: menuItem.modelData.text ?? ""
                            textFormat: Text.PlainText   // menu labels arrive over D-Bus
                            color: menuItem.modelData.enabled ? Config.fg : Config.fgDisabled
                            font.family: Config.textFont; font.pixelSize: 13
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        MatIcon {
                            visible: menuItem.modelData.hasChildren
                            text: "chevron_right"; font.pixelSize: 16
                            color: menuItem.modelData.enabled ? Config.dim : Config.fgDisabled
                        }
                    }
                    StateLayer {
                        ovRadius: 8
                        enabled: menuItem.modelData.enabled && !menuItem.modelData.hasChildren
                        onTapped: { menuItem.modelData.triggered(); pop.bar.popout = ""; }
                    }
                }
            }
        }
    }
}
