// List of audio devices (sinks or sources) with an active-device check. Emits selected(node).
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
ItemList {
    id: root
    property var nodes: []
    property int currentId: -1
    property string iconName: "speaker"
    signal selected(var node)
    last: true

    model: ScriptModel {
        values: [...root.nodes].sort((a, b) => (a.description || a.name || "").localeCompare(b.description || b.name || ""))
    }

    delegate: Item {
        id: device
        required property var modelData
        required property int index
        readonly property bool active: device.modelData?.id === root.currentId
        width: root.view.width
        implicitHeight: 52

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            Rectangle {
                implicitWidth: 34; implicitHeight: 34; radius: 17
                color: device.active ? Config.accent : Config.accentContainer
                Behavior on color { ColorAnim {} }
                MatIcon {
                    anchors.centerIn: parent; text: root.iconName; font.pixelSize: 18
                    color: device.active ? Config.accentText : Config.fg
                }
            }
            Text {
                Layout.fillWidth: true
                text: device.modelData?.description || device.modelData?.name || "Unknown"
                textFormat: Text.PlainText   // a node name straight out of pipewire
                color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; elide: Text.ElideRight
            }
            MatIcon {
                text: "check"; color: Config.accent; font.pixelSize: 18
                opacity: device.active ? 1 : 0
                Behavior on opacity { Effect {} }
            }
        }
        StateLayer {
            ovTopRadius: root.rowTop(device.index)
            ovBottomRadius: root.rowBottom(device.index)
            onTapped: root.selected(device.modelData)
        }
    }
}
