// One field of a VPN schema as whichever settings row its `kind` calls for. The only place that
// branches on kind, so a form is a Repeater over the schema and nothing else.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
Loader {
    id: fr
    // { key, kind, label, help, placeholder, options, accept, dialogTitle }
    required property var field
    property var value
    property bool first: true
    property bool last: true
    signal edited(var v)

    Layout.fillWidth: true
    sourceComponent: fr.field.kind === "bool" ? boolC
                   : fr.field.kind === "select" ? selectC
                   : fr.field.kind === "file" ? fileC
                   : textC

    Component {
        id: textC
        TextRow {
            first: fr.first; last: fr.last
            label: fr.field.label
            subtext: fr.field.help ?? ""
            placeholder: fr.field.placeholder ?? ""
            echoPassword: fr.field.kind === "password"
            value: "" + (fr.value ?? "")
            // Never `live`: a per-keystroke value would rebuild the form under the cursor.
            onEdited: t => fr.edited(fr.field.kind === "int" ? t.replace(/\D/g, "") : t)
        }
    }
    Component {
        id: boolC
        ToggleRow {
            first: fr.first; last: fr.last
            text: fr.field.label
            subtext: fr.field.help ?? ""
            checked: fr.value === true || fr.value === "yes"
            onToggled: fr.edited(checked ? "no" : "yes")
        }
    }
    Component {
        id: selectC
        SelectRow {
            first: fr.first; last: fr.last
            label: fr.field.label
            subtext: fr.field.help ?? ""
            options: fr.field.options ?? []
            value: fr.value ?? (fr.field.def ?? "")
            onSelected: v => fr.edited(v)
        }
    }
    Component {
        id: fileC
        FilePickerRow {
            first: fr.first; last: fr.last
            label: fr.field.label
            help: fr.field.help ?? ""
            accept: fr.field.accept ?? []
            dialogTitle: fr.field.dialogTitle ?? ("Choose " + fr.field.label)
            value: "" + (fr.value ?? "")
            onEdited: p => fr.edited(p)
        }
    }
}
