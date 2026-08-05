// Row with a label and a value picked from a list. Expands inline, not as a popup: every settings
// page lives in a clipped Flickable, where an overlay menu is cut off or must escape the layout.
//
// `options` takes either plain strings or { value, label, subtext } objects.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
ConnectedRect {
    id: row
    property string label: ""
    property string subtext: ""
    property var options: []
    property var value: ""
    property bool expanded: false
    // Set when the choices need their own font/colour treatment (the font picker previews faces).
    property var optionFont: null
    signal selected(var value)

    function optValue(o) { return (o && o.value !== undefined) ? o.value : o; }
    function optLabel(o) { return (o && o.label !== undefined) ? o.label : "" + o; }
    readonly property string currentLabel: {
        for (const o of row.options)
            if (row.optValue(o) === row.value) return row.optLabel(o);
        return row.value === undefined || row.value === "" ? "—" : "" + row.value;
    }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight
    clip: true
    Behavior on implicitHeight { Spatial {} }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        // --- Header ---
        Item {
            Layout.fillWidth: true
            implicitHeight: row.subtext !== "" ? 60 : 52
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 14
                spacing: 12
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
                Text {
                    text: row.currentLabel; color: Config.dim
                    font.family: Config.textFont; font.pixelSize: 13
                    elide: Text.ElideRight; Layout.maximumWidth: row.width * 0.42
                    horizontalAlignment: Text.AlignRight
                }
                MatIcon {
                    text: "expand_more"; color: Config.dim; font.pixelSize: 20
                    rotation: row.expanded ? 180 : 0
                    Behavior on rotation { Spatial {} }
                }
            }
            // Expanded, the header is only the top slice of the card, so its bottom is square.
            StateLayer {
                ovTopRadius: row.first ? row.bigRadius : row.smallRadius
                ovBottomRadius: row.expanded ? 0 : (row.last ? row.bigRadius : row.smallRadius)
                onTapped: row.expanded = !row.expanded
            }
        }

        // --- Options ---
        Repeater {
            model: row.expanded ? row.options : []
            delegate: Rectangle {
                id: opt
                required property var modelData
                readonly property bool current: row.optValue(opt.modelData) === row.value
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.bottomMargin: 6
                implicitHeight: 40
                radius: 12
                color: opt.current ? Config.accentContainer : "transparent"
                Behavior on color { ColorAnim {} }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 10
                    MatIcon {
                        text: "check"; font.pixelSize: 16
                        color: Config.accent
                        opacity: opt.current ? 1 : 0
                        Behavior on opacity { Effect {} }
                    }
                    Text {
                        text: row.optLabel(opt.modelData)
                        color: Config.fg
                        font.family: row.optionFont ? row.optionFont(opt.modelData) : Config.textFont
                        font.pixelSize: 13
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        visible: text !== ""
                        text: (opt.modelData && opt.modelData.subtext) ? opt.modelData.subtext : ""
                        color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                    }
                }
                StateLayer {
                    ovRadius: 12
                    onTapped: {
                        row.selected(row.optValue(opt.modelData));
                        row.expanded = false;
                    }
                }
            }
        }
    }
}
