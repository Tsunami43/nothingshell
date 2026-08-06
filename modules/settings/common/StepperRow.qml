// Row with a label and a numeric value adjusted by −/+ buttons. Used where a slider would be
// imprecise (idle timeouts, frame rates) — the values matter to the unit, not to the pixel.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
ConnectedRect {
    id: row
    property string label: ""
    property string subtext: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    // Overridable so a seconds value can read as "5 min" without changing what is stored.
    property string valueText: "" + row.value
    // Optional non-linear ladder: idle timeouts want 30 s → 1 min → 5 min, not 30 s → 31 s.
    // When set, it supersedes `step` (and its ends supersede from/to).
    property var ladder: null
    signal changed(real v)
    Accessible.role: Accessible.SpinBox
    Accessible.name: row.label
    Accessible.description: row.valueText

    readonly property real lo: (row.ladder && row.ladder.length) ? row.ladder[0] : row.from
    readonly property real hi: (row.ladder && row.ladder.length) ? row.ladder[row.ladder.length - 1] : row.to

    function bump(d) {
        let v;
        if (row.ladder && row.ladder.length) {
            const l = row.ladder;
            if (d > 0) { v = l[l.length - 1]; for (const c of l) if (c > row.value) { v = c; break; } }
            else { v = l[0]; for (let i = l.length - 1; i >= 0; i--) if (l[i] < row.value) { v = l[i]; break; } }
        } else {
            v = Math.min(row.to, Math.max(row.from, row.value + d * row.step));
        }
        if (v !== row.value) row.changed(v);
    }

    Layout.fillWidth: true
    implicitHeight: row.subtext !== "" ? 62 : 54

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16; anchors.rightMargin: 12
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: row.label; color: Config.fg; font.family: Config.textFont; font.pixelSize: 13
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Text {
                visible: row.subtext !== ""; text: row.subtext; color: Config.dim
                font.family: Config.textFont; font.pixelSize: 11
                Layout.fillWidth: true; elide: Text.ElideRight
            }
        }

        IconBtn {
            icon: "remove"; iconSize: 18
            opacity: row.value > row.lo ? 1 : 0.35
            onClicked: row.bump(-1)
        }
        Text {
            text: row.valueText
            color: Config.fg; font.family: Config.textFont; font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            Layout.minimumWidth: 64
        }
        IconBtn {
            icon: "add"; iconSize: 18
            opacity: row.value < row.hi ? 1 : 0.35
            onClicked: row.bump(1)
        }
    }
}
