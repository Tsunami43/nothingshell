// VPN settings, from both sources the shell knows about:
//   * NetworkManager profiles, built from the field schema in services/vpnschema.js or imported
//     from a config file, and also shown in the bar's VPN popout;
//   * custom providers, arbitrary connect/disconnect commands for what NM does not manage.
// Side by side, so one page answers "what VPNs do I have".
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs
import qs.services
import qs.components
import qs.modules.settings.common
StackView {
    id: stack
    clip: true
    initialItem: mainPage

    Component {
        id: mainPage
        PageBase {
            title: "VPN"

            SectionHeader { first: true; text: "NetworkManager profiles" }
            ItemList {
                id: nmProfiles
                visible: Net.vpnList.length > 0
                placeholderIcon: "vpn_lock"
                placeholderText: "No NetworkManager VPN profiles"
                model: ScriptModel { objectProp: "uuid"; values: [...Net.vpnList] }
                delegate: Item {
                    id: nm
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    implicitHeight: 56
                    // Below the content: the button on top of it must get its own clicks.
                    StateLayer {
                        ovTopRadius: nmProfiles.rowTop(nm.index)
                        ovBottomRadius: nmProfiles.rowBottom(nm.index)
                        onTapped: nm.modelData.active ? Net.vpnDown(nm.modelData.uuid)
                                                      : Net.vpnUp(nm.modelData.uuid)
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 8; spacing: 12
                        Rectangle {
                            implicitWidth: 34; implicitHeight: 34; radius: 17
                            color: nm.modelData.active ? Config.accent : Config.container
                            Behavior on color { ColorAnim {} }
                            MatIcon {
                                anchors.centerIn: parent
                                text: nm.modelData.active ? "vpn_lock" : "vpn_key_off"
                                font.pixelSize: 18
                                color: nm.modelData.active ? Config.accentText : Config.fg
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text {
                                text: nm.modelData.name; textFormat: Text.PlainText; color: Config.fg
                                font.family: Config.textFont; font.pixelSize: 13
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                // Name the carrier it rides on — with wired and Wi-Fi both able
                                // to be up, "Connected" alone does not say over what.
                                text: !nm.modelData.active ? "Tap to connect"
                                    : nm.modelData.device ? "Connected via " + nm.modelData.device
                                    : "Connected"
                                color: nm.modelData.active ? Config.accent : Config.dim
                                font.family: Config.textFont; font.pixelSize: 11
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }
                        IconBtn {
                            icon: "tune"; iconSize: 18; label: "Settings for " + nm.modelData.name
                            onClicked: stack.push(formPage, { uuid: nm.modelData.uuid,
                                                              kind: nm.modelData.kind })
                        }
                    }
                }
            }
            NavRow {
                first: true; last: false
                icon: "add"; label: "Add a VPN"
                status: "IKEv2, OpenVPN, WireGuard"
                onClicked: stack.push(typePage)
            }
            NavRow {
                first: false; last: true
                icon: "file_open"; label: "Import a configuration"
                status: "An .ovpn or WireGuard .conf you already have"
                onClicked: stack.push(importPage)
            }

            SectionHeader { text: "Custom provider" }
            ToggleRow {
                text: "Connection"
                subtext: VPN.active ? (VPN.connected ? "Connected · " + VPN.active.name : VPN.busy ? "Working…" : VPN.active.name) : "No provider selected"
                checked: VPN.connected
                onToggled: { if (VPN.active && !VPN.busy) VPN.toggle(); }
            }

            SectionHeader { text: "Providers" }
            ItemList {
                id: providers
                Layout.fillHeight: true
                placeholderIcon: "vpn_key_off"
                placeholderText: "No VPN providers configured"
                model: ScriptModel { values: [...VPN.providers] }
                delegate: Item {
                    id: prov
                    required property var modelData
                    required property int index
                    readonly property bool selected: prov.index === VPN.selectedIndex
                    readonly property bool isConnected: prov.selected && VPN.connected
                    width: ListView.view.width
                    implicitHeight: 56
                    // Below the content: the edit button on top of it must get its own clicks.
                    StateLayer {
                        ovTopRadius: providers.rowTop(prov.index)
                        ovBottomRadius: providers.rowBottom(prov.index)
                        onTapped: VPN.setActive(prov.index)
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 8; spacing: 12
                        Rectangle {
                            implicitWidth: 34; implicitHeight: 34; radius: 17
                            color: prov.isConnected ? Config.accent : prov.selected ? Config.accentContainer : Config.container
                            MatIcon {
                                anchors.centerIn: parent
                                text: prov.isConnected || prov.selected ? "vpn_key" : "vpn_key_off"
                                font.pixelSize: 18; color: prov.isConnected ? Config.accentText : Config.fg
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text {
                                text: prov.modelData.name || "Unnamed"; textFormat: Text.PlainText; color: Config.fg
                                font.family: Config.textFont; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                text: prov.isConnected ? "Connected" : prov.selected ? "Selected · tap edit" : "Tap to select"
                                color: prov.isConnected ? Config.accent : Config.dim
                                font.family: Config.textFont; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }
                        IconBtn {
                            icon: "edit"; label: "Edit " + prov.modelData.name
                            onClicked: stack.push(editPage, { editIndex: prov.index })
                        }
                    }
                }
            }

            NavRow {
                first: true; last: true
                icon: "add"; label: "Add provider"
                onClicked: stack.push(editPage, { editIndex: -1 })
            }
        }
    }

    // --- Pick a VPN technology ---
    Component {
        id: typePage
        PageBase {
            id: tp
            title: "Add a VPN"
            isSubPage: true
            onBack: stack.pop()

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: "The profile is created in NetworkManager, so it also shows up in the bar and "
                      + "survives a restart of the shell. Only plugins installed on this machine "
                      + "can be configured."
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
            ItemList {
                id: typeList
                Layout.fillHeight: true
                model: ScriptModel { objectProp: "id"; values: [...VPN.types] }
                delegate: Item {
                    id: ty
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    implicitHeight: 62
                    opacity: ty.modelData.available ? 1 : 0.45
                    StateLayer {
                        enabled: ty.modelData.available
                        ovTopRadius: typeList.rowTop(ty.index)
                        ovBottomRadius: typeList.rowBottom(ty.index)
                        onTapped: ty.modelData.importOnly
                            ? stack.push(importPage, { typeId: ty.modelData.id })
                            : stack.push(formPage, { typeId: ty.modelData.id })
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 12
                        MatIcon { text: ty.modelData.icon; color: Config.fg; font.pixelSize: 20 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text {
                                text: ty.modelData.label; color: Config.fg
                                font.family: Config.textFont; font.pixelSize: 13; font.bold: true
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                text: ty.modelData.available ? ty.modelData.subtext
                                    : "Plugin not installed — needs " + ty.modelData.package
                                color: ty.modelData.available ? Config.dim : Config.warning
                                font.family: Config.textFont; font.pixelSize: 11
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }
                        MatIcon {
                            text: ty.modelData.available ? "chevron_right" : "block"
                            color: Config.dim; font.pixelSize: 20
                        }
                    }
                }
            }
        }
    }

    // --- Import an existing configuration file ---
    Component {
        id: importPage
        PageBase {
            id: imp
            // Set when reached from a type; empty means the generic entry, where the extension decides.
            property string typeId: ""
            property string path: ""
            readonly property var type: imp.typeId ? VPN.typeById(imp.typeId) : null
            title: imp.type ? "Import " + imp.type.label : "Import a VPN configuration"
            isSubPage: true
            onBack: stack.pop()

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: "Hands the file to `nmcli connection import`, which reads the whole thing — "
                      + "keys, peers and routes included. The profile then appears in the list and "
                      + "in the bar."
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
            FilePickerRow {
                first: true; last: true
                label: "Configuration file"
                dialogTitle: "Choose a VPN configuration"
                accept: imp.type?.importAccept ?? [".ovpn", ".conf"]
                value: imp.path
                onEdited: p => imp.path = p
            }
            ButtonRow {
                first: true; last: true
                icon: "download"; label: "Import"
                enabled: imp.path.length > 0
                onClicked: { VPN.importConfig(imp.path, imp.type?.importType ?? ""); stack.pop(); }
            }
        }
    }

    // --- Create or edit a NetworkManager profile ---
    Component {
        id: formPage
        PageBase {
            id: form
            property string uuid: ""            // empty means "creating"
            property string typeId: ""
            property string kind: "vpn"         // nmcli connection type, for the wireguard case
            property string name: ""
            property var values: ({})
            property var existing: ({})         // the vpn.data an edit was loaded from
            property bool showAdvanced: false
            property bool armed: false
            readonly property var type: form.typeId ? VPN.typeById(form.typeId) : null
            readonly property var missing: form.type ? VPN.missingRequired(form.type, form.values) : []
            // Which fields are on screen, in order; recomputed whenever a value changes.
            readonly property var resolved: form.type ? VPN.resolveValues(form.type, form.values) : ({})
            readonly property var shown: (form.type?.fields ?? [])
                .filter(f => VPN.fieldVisible(f, form.resolved, form.showAdvanced))
                .map(f => f.key)

            title: form.uuid ? (form.name || "Edit VPN") : ("Add " + (form.type?.label ?? "VPN"))
            isSubPage: true
            onBack: stack.pop()

            // A `var` map fires no change signal when mutated in place, so every write replaces it.
            function setValue(k, v) {
                const o = Object.assign({}, form.values);
                o[k] = v;
                form.values = o;
            }

            Component.onCompleted: if (form.uuid) VPN.loadProfile(form.uuid)
            Connections {
                target: VPN
                function onLoaded(profile) {
                    if (profile.uuid !== form.uuid) return;
                    form.name = profile.name;
                    form.typeId = profile.typeId;
                    form.existing = profile.values;
                    form.values = profile.values;
                }
                // pop(null): creating came through the type picker and has two pages to unwind.
                function onSaved(uuid) { stack.pop(null); }   // qmllint disable signal-handler-parameters
            }

            TextRow {
                first: true; last: true
                label: "Name"
                placeholder: "Office"
                value: form.name
                onEdited: t => form.name = t
            }

            // No schema for this plugin, or a native WireGuard profile: rename and delete only.
            Text {
                visible: form.uuid !== "" && !form.type
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: form.kind === "wireguard"
                    ? "WireGuard profiles carry their keys and peers in the profile itself — edit "
                      + "the .conf and import it again to change them."
                    : "This profile was made by something else and uses settings this page does not "
                      + "know. Its name can be changed here; the rest, only in nm-connection-editor."
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: form.type?.fields ?? []
                delegate: FieldRow {
                    id: fieldRow
                    required property var modelData
                    field: modelData
                    // Visibility, not a model change, or a row would lose what was being typed in it.
                    visible: form.shown.indexOf(modelData.key) >= 0
                    value: form.resolved[modelData.key] ?? ""
                    onEdited: v => form.setValue(modelData.key, v)
                }
            }

            ToggleRow {
                visible: (form.type?.fields ?? []).some(f => f.advanced)
                text: "Advanced options"
                subtext: "Ports, algorithm proposals, traffic selectors"
                checked: form.showAdvanced
                onToggled: form.showAdvanced = !form.showAdvanced
            }

            InfoRow {
                visible: VPN.lastError !== ""
                icon: "error"; label: "nmcli"; value: VPN.lastError
            }

            ButtonRow {
                first: true; last: true
                icon: "check"
                label: form.uuid ? "Save" : "Add VPN"
                subtext: form.name === "" ? "Give it a name first"
                       : form.missing.length > 0 ? "Still needed: " + form.missing.join(", ") : ""
                busy: VPN.saving
                enabled: form.name !== "" && (!form.type || form.missing.length === 0)
                onClicked: {
                    // Nothing to write but the name; an empty dict leaves vpn.data alone.
                    const built = form.type
                        ? VPN.buildProfile(form.type, form.values, form.existing)
                        : { data: ({}), secrets: ({}), cleared: [] };
                    VPN.saveProfile({ uuid: form.uuid, name: form.name,
                                      service: form.type?.service ?? "",
                                      data: built.data, secrets: built.secrets,
                                      cleared: built.cleared });
                }
            }

            // Behind opening the profile, the way "Forget this network" is, plus an arming tap.
            ButtonRow {
                visible: form.uuid !== ""
                first: true; last: true
                destructive: true
                icon: "delete"
                label: form.armed ? "Tap again to delete" : "Delete this profile"
                subtext: form.armed ? "" : "Removes it from NetworkManager"
                onClicked: {
                    if (!form.armed) { form.armed = true; armReset.restart(); return; }
                    Net.deleteProfile(form.uuid);
                    stack.pop();
                }
            }
            Timer { id: armReset; interval: 4000; onTriggered: form.armed = false }
        }
    }

    // --- Add / edit a custom provider ---
    Component {
        id: editPage
        PageBase {
            id: ep
            property int editIndex: -1
            property string name: ""
            property string iface: ""
            property string connectCmd: ""
            property string disconnectCmd: ""
            readonly property var existing: editIndex >= 0 ? VPN.providers[editIndex] : null
            title: editIndex >= 0 ? "Edit provider" : "Add provider"
            isSubPage: true
            onBack: stack.pop()

            Component.onCompleted: {
                if (!ep.existing) return;
                ep.name = ep.existing.name ?? "";
                ep.iface = ep.existing.iface ?? "";
                ep.connectCmd = ep.existing.connectCmd ?? "";
                ep.disconnectCmd = ep.existing.disconnectCmd ?? "";
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: "For anything NetworkManager does not manage — tailscale, warp-cli, a bare "
                      + "wg-quick. The commands run through `sh -c`; the interface is how the shell "
                      + "tells whether it is up."
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            TextRow {
                first: true; last: false
                label: "Name"; placeholder: "Home WireGuard"
                value: ep.name; onEdited: t => ep.name = t
            }
            TextRow {
                first: false; last: true
                label: "Interface"; placeholder: "wg0, tailscale0"
                subtext: "Checked under /sys/class/net to report the connection state"
                value: ep.iface; onEdited: t => ep.iface = t
            }
            TextRow {
                first: true; last: false
                label: "Connect command"; placeholder: "wg-quick up wg0"
                value: ep.connectCmd; onEdited: t => ep.connectCmd = t
            }
            TextRow {
                first: false; last: true
                label: "Disconnect command"; placeholder: "wg-quick down wg0"
                value: ep.disconnectCmd; onEdited: t => ep.disconnectCmd = t
            }

            ButtonRow {
                first: true; last: true
                icon: "check"
                label: ep.editIndex >= 0 ? "Save" : "Add provider"
                subtext: ep.name === "" ? "Give it a name first" : ""
                enabled: ep.name !== ""
                onClicked: {
                    const p = { name: ep.name, iface: ep.iface,
                                connectCmd: ep.connectCmd, disconnectCmd: ep.disconnectCmd };
                    if (ep.editIndex >= 0) VPN.updateProvider(ep.editIndex, p);
                    else VPN.addProvider(p);
                    stack.pop();
                }
            }
            ButtonRow {
                visible: ep.editIndex >= 0
                first: true; last: true
                destructive: true
                icon: "delete"; label: "Delete this provider"
                onClicked: { VPN.deleteProvider(ep.editIndex); stack.pop(); }
            }
        }
    }
}
