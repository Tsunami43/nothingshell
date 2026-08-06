// Row with a label and an editable single-line value. `edited` fires on Enter or focus loss,
// not per keystroke, so a half-typed path never reaches the setting it drives.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
ConnectedRect {
    id: row
    property string label: ""
    property string subtext: ""
    property string value: ""
    property string placeholder: ""
    property bool echoPassword: false
    // Emit on every keystroke instead of on commit — for a search box, where a half-typed value
    // is exactly what should be acted on.
    property bool live: false
    property alias input: field
    signal edited(string text)
    // The field announces itself; this names what it is for.
    Accessible.role: Accessible.EditableText
    Accessible.name: row.label
    Accessible.description: row.subtext

    // Follow the source while the field is idle; while editing, leave what is being typed alone.
    onValueChanged: if (!field.activeFocus) field.text = row.value

    Layout.fillWidth: true
    implicitHeight: row.subtext !== "" ? 72 : 62

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16; anchors.rightMargin: 16
        anchors.topMargin: 8; anchors.bottomMargin: 8
        spacing: 1

        Text {
            text: row.label; color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
            Layout.fillWidth: true; elide: Text.ElideRight
        }
        Text {
            visible: row.subtext !== ""; text: row.subtext; color: Config.dim
            font.family: Config.textFont; font.pixelSize: 10
            Layout.fillWidth: true; elide: Text.ElideRight
        }
        TextInput {
            id: field
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: row.value
            color: Config.fg
            font.family: Config.textFont
            font.pixelSize: 13
            selectByMouse: true
            selectionColor: Config.accent
            selectedTextColor: Config.accentText
            echoMode: row.echoPassword ? TextInput.Password : TextInput.Normal
            clip: true
            onAccepted: { row.edited(field.text); focus = false; }
            onActiveFocusChanged: if (!activeFocus && field.text !== row.value) row.edited(field.text)
            onTextChanged: if (row.live && field.text !== row.value) row.edited(field.text)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text.length === 0 && row.placeholder !== ""
                text: row.placeholder
                color: Config.fgDisabled
                font.family: Config.textFont
                font.pixelSize: 13
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: field.activeFocus ? Config.accent : Config.outlineVariant
            Behavior on color { ColorAnim {} }
        }
    }
}
