// Row holding a file path, with a folder button that opens the system file dialog. The path stays
// typeable: somewhere like /etc/ipsec.d/cacerts is faster pasted than browsed to.
//
// The state layer sits below the content, or it would swallow the two buttons' clicks.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import qs
import qs.components
ConnectedRect {
    id: row
    property string label: ""
    property string help: ""
    property string value: ""
    property string dialogTitle: "Choose a file"
    // [".pem", ".crt"] becomes one filter, plus "All files".
    property var accept: []
    signal edited(string path)

    readonly property string base: row.value ? row.value.split("/").pop() : ""
    readonly property string dirPart: {
        const i = row.value.lastIndexOf("/");
        return i > 0 ? row.value.slice(0, i) : "";
    }
    Accessible.role: Accessible.EditableText
    Accessible.name: row.label
    Accessible.description: row.help

    Layout.fillWidth: true
    implicitHeight: row.help !== "" ? 78 : 68

    StateLayer { onTapped: dlg.open() }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16; anchors.rightMargin: 8
        anchors.topMargin: 8; anchors.bottomMargin: 8
        spacing: 1

        Text {
            text: row.label; color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
            Layout.fillWidth: true; elide: Text.ElideRight
        }
        Text {
            visible: row.help !== ""; text: row.help; color: Config.dim
            font.family: Config.textFont; font.pixelSize: 10
            Layout.fillWidth: true; elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            TextInput {
                id: field
                Layout.fillWidth: true
                text: row.value
                color: Config.fg
                font.family: Config.textFont
                font.pixelSize: 13
                selectByMouse: true
                selectionColor: Config.accent
                selectedTextColor: Config.accentText
                clip: true
                // Follow the source while idle; leave what is being typed alone.
                onActiveFocusChanged: if (!activeFocus && field.text !== row.value) row.edited(field.text)
                onAccepted: { row.edited(field.text); focus = false; }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text.length === 0
                    text: "No file chosen"
                    color: Config.fgDisabled
                    font.family: Config.textFont; font.pixelSize: 13
                }
            }
            IconBtn {
                visible: row.value !== ""
                icon: "close"; iconSize: 16; label: "Clear " + row.label
                onClicked: { field.text = ""; row.edited(""); }
            }
            IconBtn {
                icon: "folder_open"; iconSize: 18; label: "Browse for " + row.label
                onClicked: dlg.open()
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: field.activeFocus ? Config.accent : Config.outlineVariant
            Behavior on color { ColorAnim {} }
        }
    }
    // Follow the value while the field is not being edited.
    onValueChanged: if (!field.activeFocus) field.text = row.value

    FileDialog {
        id: dlg
        title: row.dialogTitle
        // Reopen where the current value lives, so the second file of a pair is one click.
        currentFolder: row.dirPart ? "file://" + row.dirPart : "file://" + Paths.home
        nameFilters: {
            const out = [];
            if (row.accept.length > 0)
                out.push("Accepted (" + row.accept.map(e => "*" + e).join(" ") + ")");
            out.push("All files (*)");
            return out;
        }
        onAccepted: {
            const p = ("" + dlg.selectedFile).replace(/^file:\/\//, "");
            field.text = p;
            row.edited(p);
        }
    }
}
