// Settings line: a label plus a segmented control. `values` carries the stored values, `labels`
// the display text (defaults to `values`), and `picked` hands back the chosen value as a string —
// numeric settings (fps) parse it back, which keeps the comparison here type-agnostic.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs

RowLayout {
    id: opt
    property string label
    property var values: []
    property var labels: null
    property var current
    signal picked(string value)

    Layout.fillWidth: true
    spacing: 10

    Text {
        Layout.preferredWidth: 78
        text: opt.label
        color: Config.dim
        font.family: Config.textFont; font.pixelSize: 11
    }
    Row {
        spacing: 6
        Repeater {
            model: opt.values
            Seg {
                required property var modelData
                required property int index
                label: String(opt.labels ? opt.labels[index] : modelData)
                on: String(opt.current) === String(modelData)
                onPicked: opt.picked(String(modelData))
            }
        }
    }
    Item { Layout.fillWidth: true }
}
