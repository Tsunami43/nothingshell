// Wi-Fi network list: signal icon + SSID + lock/active, sorted active→connecting→saved→strength.
// Tapping an inactive secured/unsaved network expands an inline password field; open/saved
// networks connect directly; the active network raises openDetail(ssid).
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components
ItemList {
    id: root
    property int limit: 0
    property string pwSsid: ""
    signal openDetail(string ssid)

    function signalIcon(s) {
        if (s >= 75) return "network_wifi";
        if (s >= 50) return "network_wifi_3_bar";
        if (s >= 30) return "network_wifi_2_bar";
        return "network_wifi_1_bar";
    }

    placeholderIcon: Net.wifiEnabled ? "wifi_find" : "signal_wifi_off"
    placeholderText: Net.wifiEnabled ? "No networks found" : "Wi-Fi disabled"

    model: ScriptModel {
        values: {
            if (!Net.wifiEnabled) return [];
            const connecting = Net.connectingSsid();
            const rank = n => n.active ? 0 : n.ssid === connecting ? 1 : Net.hasSavedProfile(n.ssid) ? 2 : 3;
            const sorted = [...Net.networks].sort((a, b) => rank(a) - rank(b) || b.strength - a.strength);
            if (root.limit > 0 && sorted.length > root.limit) sorted.length = root.limit;
            return sorted;
        }
    }

    delegate: Column {
        id: net
        required property int index
        required property var modelData
        readonly property bool secure: net.modelData.isSecure
        readonly property bool saved: Net.hasSavedProfile(net.modelData.ssid)
        readonly property bool prompting: root.pwSsid === net.modelData.ssid
        width: root.view.width

        function onTap() {
            if (net.modelData.active) { root.openDetail(net.modelData.ssid); return; }
            if (net.saved || !net.secure) { Net.connectToNetwork(net.modelData.ssid, "", net.modelData.bssid, null); return; }
            root.pwSsid = net.prompting ? "" : net.modelData.ssid;
        }

        Item {
            width: parent.width
            height: 52
            // Below the content: the connect button on top of it must get its own clicks.
            StateLayer {
                ovTopRadius: root.rowTop(net.index)
                ovBottomRadius: net.prompting ? 0 : root.rowBottom(net.index)
                onTapped: net.onTap()
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 10; spacing: 12
                MatIcon { text: root.signalIcon(net.modelData.strength); color: Config.fg; font.pixelSize: 20 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text {
                        // PlainText: an SSID is chosen by whoever runs the access point.
                        text: net.modelData.ssid || "(hidden)"; textFormat: Text.PlainText; color: Config.fg
                        font.family: Config.textFont; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        visible: net.modelData.active || net.saved || net.prompting
                        text: net.modelData.active ? "Connected" : net.prompting ? "Enter password" : "Saved"
                        color: net.modelData.active ? Config.accent : Config.dim
                        font.family: Config.textFont; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight
                    }
                }
                MatIcon { visible: net.secure; text: "lock"; color: Config.dim; font.pixelSize: 14 }
                // Explicit connect/disconnect, same affordance the wired ports have. For a
                // secured network with no profile this opens the password field, as a tap does.
                IconBtn {
                    icon: net.modelData.active ? "link_off" : "link"
                    tint: net.modelData.active ? Config.danger : Config.accent
                    iconSize: 18
                    onClicked: net.modelData.active ? Net.disconnectFromNetwork() : net.onTap()
                }
            }
        }

        // Inline password field for secured, unsaved networks.
        Loader {
            width: parent.width
            active: net.prompting
            visible: active
            sourceComponent: RowLayout {
                width: net.width
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16; Layout.bottomMargin: 8
                    implicitHeight: 38; radius: 10; color: Config.bg
                    border.width: 1; border.color: Config.outline
                    TextInput {
                        id: pwInput
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Config.fg; font.family: Config.textFont; font.pixelSize: 13
                        echoMode: TextInput.Password; clip: true
                        focus: net.prompting
                        onAccepted: connectBtn.go()
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pwInput.text === ""; text: "Password"; color: Config.dim
                            font.family: Config.textFont; font.pixelSize: 13
                        }
                    }
                }
                IconBtn {
                    id: connectBtn
                    Layout.rightMargin: 16; Layout.bottomMargin: 8
                    icon: "arrow_forward"; active: pwInput.text.length > 0
                    function go() {
                        if (pwInput.text.length === 0) return;
                        Net.connectToNetwork(net.modelData.ssid, pwInput.text, net.modelData.bssid, null);
                        root.pwSsid = "";
                    }
                    onClicked: go()
                }
            }
        }
    }
}
