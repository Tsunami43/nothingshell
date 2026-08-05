// A ConnectedRect wrapping a non-interactive ListView, with an icon+text placeholder when empty.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
ConnectedRect {
    id: list
    property alias model: view.model
    property alias delegate: view.delegate
    property alias view: view
    property string placeholderIcon: ""
    property string placeholderText: ""
    readonly property int count: view.count

    // Corner radii for the row at `i`, so a row's state layer matches the card it sits in:
    // only the first and last rows touch the rounded ends, the rest are square.
    function rowTop(i) { return i === 0 ? (list.first ? list.bigRadius : list.smallRadius) : 0; }
    function rowBottom(i) { return i === list.count - 1 ? (list.last ? list.bigRadius : list.smallRadius) : 0; }

    Layout.fillWidth: true
    implicitHeight: view.count > 0 ? view.contentHeight : 68
    clip: true
    ListView {
        id: view
        anchors.fill: parent
        interactive: false
        visible: view.count > 0
        spacing: 0

        // Rows fade + slide in, fade out, and reflow smoothly (when the model reports granular changes).
        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1
                                  duration: Motion.effectDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectCurve }
                NumberAnimation { property: "x"; from: 14; to: 0
                                  duration: Motion.spatialDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve }
            }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0
                              duration: Motion.effectDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectCurve }
        }
        move: Transition {
            NumberAnimation { property: "y"; duration: Motion.spatialDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: Motion.spatialDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve }
        }
    }
    ColumnLayout {
        anchors.centerIn: parent
        visible: view.count === 0
        spacing: 6
        MatIcon { Layout.alignment: Qt.AlignHCenter; text: list.placeholderIcon; color: Config.dim; font.pixelSize: 26 }
        Text {
            Layout.alignment: Qt.AlignHCenter; text: list.placeholderText; color: Config.dim
            font.family: Config.textFont; font.pixelSize: 12
        }
    }
}
