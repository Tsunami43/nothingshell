// Flat metric gauge: a progress ring with the reading inside and a caption under it. No card
// behind it on purpose — the Performance tab groups the gauges with spacing and a rule, so five
// of them read as one row of instruments instead of five boxes.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs

ColumnLayout {
    id: gauge
    property string icon
    property string label
    property real value: 0
    property string valueText
    property string sub: ""     // optional small readout inside the ring (e.g. GPU temp)
    property color tint: Config.accent
    property int ring: 92
    readonly property int stroke: 7

    spacing: 6

    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: gauge.ring; implicitHeight: gauge.ring

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Config.surface
                strokeWidth: gauge.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: gauge.ring / 2; centerY: gauge.ring / 2
                    radiusX: (gauge.ring - gauge.stroke) / 2; radiusY: (gauge.ring - gauge.stroke) / 2
                    startAngle: -90; sweepAngle: 360
                }
            }
            ShapePath {
                strokeColor: gauge.tint
                strokeWidth: gauge.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: gauge.ring / 2; centerY: gauge.ring / 2
                    radiusX: (gauge.ring - gauge.stroke) / 2; radiusY: (gauge.ring - gauge.stroke) / 2
                    startAngle: -90
                    // Samples land once a second, so ease between them — the ring reads as a
                    // needle settling rather than a value teleporting.
                    sweepAngle: 360 * Math.max(0, Math.min(1, gauge.value))
                    Behavior on sweepAngle { Effect {} }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: gauge.valueText
                color: Config.fg; font.family: Config.textFont; font.pixelSize: 17; font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: gauge.sub.length > 0
                text: gauge.sub
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 10
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 5
        MatIcon { text: gauge.icon; font.pixelSize: 14; color: gauge.tint }
        Text { text: gauge.label; color: Config.dim; font.family: Config.textFont; font.pixelSize: 12 }
    }
}
