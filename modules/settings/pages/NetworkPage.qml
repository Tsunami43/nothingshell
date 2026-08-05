// Network settings, top to bottom: every wired port (connected or free), then the Wi-Fi
// toggle with the scan list below it while the radio is on. Sub-pages cover All / Saved /
// Add, a per-network detail, and a per-interface detail shared by wired and wireless.
// VPN lives on its own nav page.
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
            id: netMain
            title: "Network"

            // Periodic rescan while the page is visible and Wi-Fi is on. `netMain.visible`, not a
            // bare `visible`: a Timer has no such property, so the unqualified form silently
            // resolved up the scope chain to this page — right by accident, and wrong the day a
            // Timer gains one or this moves into something that has its own.
            Timer {
                running: netMain.visible && Net.wifiEnabled
                repeat: true; triggeredOnStart: true; interval: 10000
                onTriggered: Net.rescanWifi()
            }

            // Ethernet — every managed wired port, plugged or not, so an idle second port
            // is visible instead of silently absent. Tap a port for addressing and profiles.
            SectionHeader { first: true; visible: Net.hasEthernetPort; text: "Ethernet" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Repeater {
                    model: Net.ethernetLinks
                    NavRow {
                        id: ethRow
                        required property int index
                        required property var modelData
                        readonly property bool up: ethRow.modelData.stateCode >= 100
                        first: ethRow.index === 0
                        last: ethRow.index === Net.ethernetLinks.length - 1
                        icon: Net.linkIcon(ethRow.modelData)
                        label: ethRow.modelData.device
                        status: [
                            ethRow.modelData.connection || Net.linkState(ethRow.modelData),
                            ethRow.modelData.ip4 ? ethRow.modelData.ip4.split("/")[0] : "",
                            ethRow.modelData.isDefault ? "primary" : ""
                        ].filter(Boolean).join(" · ")
                        // No button while the port is unavailable — with no carrier there is
                        // nothing to connect to, and nmcli would just fail.
                        actionIcon: ethRow.modelData.stateCode < 30 ? "" : (ethRow.up ? "link_off" : "link")
                        actionTint: ethRow.up ? Config.danger : Config.accent
                        onActionClicked: ethRow.up ? Net.disconnectDevice(ethRow.modelData.device)
                                                   : Net.connectDevice(ethRow.modelData.device)
                        onClicked: stack.push(linkPage, { device: ethRow.modelData.device })
                    }
                }
            }

            SectionHeader { text: "Wi-Fi" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ToggleRow {
                    first: true; last: false
                    text: "Wi-Fi"; checked: Net.wifiEnabled
                    onToggled: Net.enableWifi(!Net.wifiEnabled, null)
                }
                // Scan results only exist while the radio is on — with it off the row would
                // just be an empty placeholder, so it goes away entirely.
                NetworkList {
                    visible: Net.wifiEnabled
                    first: false; last: false
                    limit: 6
                    onOpenDetail: ssid => stack.push(detailPage, { ssid })
                }
                NavRow {
                    visible: Net.wifiEnabled && Net.networks.length > 6
                    first: false; last: false
                    icon: "expand_content"; label: "Show all networks (" + Net.networks.length + ")"
                    onClicked: stack.push(allPage)
                }
                NavRow {
                    first: false; last: false
                    icon: "bookmark"; label: "Saved networks"
                    onClicked: { Net.loadSavedConnections(null); stack.push(savedPage); }
                }
                NavRow {
                    first: false; last: true
                    icon: "add"; label: "Add network"
                    onClicked: stack.push(addPage)
                }
            }
        }
    }

    // --- All networks ---
    Component {
        id: allPage
        PageBase {
            title: "All networks"
            isSubPage: true
            onBack: stack.pop()
            NetworkList {
                Layout.fillHeight: true
                onOpenDetail: ssid => stack.push(detailPage, { ssid })
            }
        }
    }

    // --- Saved networks ---
    Component {
        id: savedPage
        PageBase {
            title: "Saved networks"
            isSubPage: true
            onBack: stack.pop()
            ItemList {
                Layout.fillHeight: true
                placeholderIcon: "bookmark_border"
                placeholderText: "No saved networks"
                model: Net.savedConnectionSsids
                delegate: Item {
                    id: sv
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: 50
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 10; spacing: 12
                        MatIcon { text: "wifi"; color: Config.fg; font.pixelSize: 18 }
                        Text {
                            // PlainText: a saved SSID, named by its access point.
                            Layout.fillWidth: true; text: sv.modelData; textFormat: Text.PlainText; color: Config.fg
                            font.family: Config.textFont; font.pixelSize: 13; elide: Text.ElideRight
                        }
                        IconBtn { icon: "delete"; tint: Config.error; onClicked: Net.forgetNetwork(sv.modelData, null) }
                    }
                }
            }
        }
    }

    // --- Add network ---
    Component {
        id: addPage
        PageBase {
            id: addRoot
            title: "Add network"
            isSubPage: true
            onBack: stack.pop()

            property bool secured: true
            property bool hidden: false

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 48; topLeftRadius: 20; topRightRadius: 20
                    bottomLeftRadius: 6; bottomRightRadius: 6; color: Config.container
                    TextInput {
                        id: ssidInput
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; clip: true
                        Text {
                            anchors.verticalCenter: parent.verticalCenter; visible: ssidInput.text === ""
                            text: "Network name (SSID)"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 13
                        }
                    }
                }
                ToggleRow { first: false; last: false; text: "Secured (WPA/WPA2)"; checked: addRoot.secured; onToggled: addRoot.secured = !addRoot.secured }
                Rectangle {
                    Layout.fillWidth: true; visible: addRoot.secured; implicitHeight: 48; radius: 6
                    color: Config.container
                    TextInput {
                        id: passInput
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter; echoMode: TextInput.Password
                        color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; clip: true
                        Text {
                            anchors.verticalCenter: parent.verticalCenter; visible: passInput.text === ""
                            text: "Password"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 13
                        }
                    }
                }
                ToggleRow { first: false; last: true; text: "Hidden network"; checked: addRoot.hidden; onToggled: addRoot.hidden = !addRoot.hidden }

                Rectangle {
                    Layout.fillWidth: true; Layout.topMargin: 12; implicitHeight: 46; radius: 14
                    color: ssidInput.text.length > 0 ? Config.accent : Config.container
                    Text {
                        anchors.centerIn: parent; text: "Add & connect"
                        color: ssidInput.text.length > 0 ? Config.accentText : Config.dim
                        font.family: Config.textFont; font.pixelSize: 14; font.bold: true
                    }
                    StateLayer {
                        ovRadius: 14
                        onTapped: {
                            if (ssidInput.text.length === 0) return;
                            Net.addHiddenNetwork(ssidInput.text, passInput.text, addRoot.secured ? "wpa" : "none", addRoot.hidden, null);
                            stack.pop();
                        }
                    }
                }
            }
        }
    }

    // --- Network detail (active/saved) ---
    Component {
        id: detailPage
        PageBase {
            id: detRoot
            property string ssid: ""
            title: detRoot.ssid
            isSubPage: true
            onBack: stack.pop()
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                NavRow {
                    first: true; last: false
                    icon: "link_off"; label: "Disconnect"
                    onClicked: { Net.disconnectFromNetwork(); stack.pop(); }
                }
                NavRow {
                    first: false; last: false
                    icon: "delete"; label: "Forget this network"
                    onClicked: { Net.forgetNetwork(detRoot.ssid, null); stack.pop(); }
                }
                // Addressing for the connected network lives on the shared interface page.
                NavRow {
                    visible: detRoot.ssid === Net.wifiSsid && Net.activeWifi !== null
                    first: false; last: true
                    icon: "info"; label: "Interface details"
                    status: Net.activeWifi?.device ?? ""
                    onClicked: stack.push(linkPage, { device: Net.activeWifi?.device ?? "" })
                }
            }
        }
    }

    // --- Interface detail (wired or wireless) ---
    // Keyed by device name and re-resolved from Net.links, so the rows follow the live state
    // instead of freezing whatever was true when the page was pushed.
    Component {
        id: linkPage
        PageBase {
            id: linkRoot
            property string device: ""
            readonly property var link: Net.links.find(l => l.device === linkRoot.device) ?? null
            readonly property bool wired: linkRoot.link?.type === "ethernet"
            readonly property bool up: (linkRoot.link?.stateCode ?? 0) >= 100
            title: linkRoot.device
            isSubPage: true
            onBack: stack.pop()

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                InfoRow {
                    first: true; last: false
                    icon: Net.linkIcon(linkRoot.link); label: "Status"
                    value: Net.linkState(linkRoot.link)
                }
                InfoRow {
                    visible: (linkRoot.link?.connection ?? "") !== ""
                    first: false; last: false
                    icon: "badge"; label: linkRoot.wired ? "Profile" : "Network"
                    value: linkRoot.link?.connection ?? ""
                }
                // Which link the kernel actually sends traffic through — the question a
                // second active interface raises and nothing else on this page answers.
                InfoRow {
                    visible: linkRoot.up
                    first: false; last: false
                    icon: "alt_route"; label: "Default route"
                    value: linkRoot.link?.isDefault === true
                        ? "Yes" + (Net.defaultGateway ? " · via " + Net.defaultGateway : "")
                        : (Net.defaultDevice ? "No · " + Net.defaultDevice : "No")
                }
                InfoRow {
                    visible: (linkRoot.link?.ip4 ?? "") !== ""
                    first: false; last: false
                    icon: "language"; label: "IPv4"; value: linkRoot.link?.ip4 ?? ""
                }
                InfoRow {
                    visible: (linkRoot.link?.gateway ?? "") !== ""
                    first: false; last: false
                    icon: "router"; label: "Gateway"; value: linkRoot.link?.gateway ?? ""
                }
                InfoRow {
                    visible: (linkRoot.link?.dns?.length ?? 0) > 0
                    first: false; last: false
                    icon: "dns"; label: "DNS"; value: (linkRoot.link?.dns ?? []).join(", ")
                }
                InfoRow {
                    visible: (linkRoot.link?.ip6 ?? "") !== ""
                    first: false; last: false
                    icon: "language"; label: "IPv6"; value: linkRoot.link?.ip6 ?? ""
                }
                InfoRow {
                    visible: (linkRoot.link?.speed ?? "") !== ""
                    first: false; last: false
                    icon: "speed"; label: "Link speed"; value: linkRoot.link?.speed ?? ""
                }
                InfoRow {
                    first: false; last: true
                    icon: "fingerprint"; label: "MAC"; value: linkRoot.link?.mac ?? ""
                }
            }

            // Wired ports get connect/disconnect here; Wi-Fi keeps its own detail page for that.
            SectionHeader { visible: linkRoot.wired; text: "Actions" }
            NavRow {
                visible: linkRoot.wired
                icon: linkRoot.up ? "link_off" : "link"
                label: linkRoot.up ? "Disconnect" : "Connect"
                onClicked: {
                    if (linkRoot.up) Net.disconnectDevice(linkRoot.device);
                    else Net.connectDevice(linkRoot.device);
                }
            }

            SectionHeader { visible: linkRoot.wired && wiredProfiles.count > 0; text: "Wired profiles" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Repeater {
                    id: wiredProfiles
                    model: linkRoot.wired ? Net.profilesFor(linkRoot.device) : []
                    NavRow {
                        id: profRow
                        required property int index
                        required property var modelData
                        first: profRow.index === 0
                        last: profRow.index === wiredProfiles.count - 1
                        icon: profRow.modelData.active ? "check_circle" : "cable"
                        label: profRow.modelData.name
                        status: profRow.modelData.active ? "Active on " + profRow.modelData.device : "Tap to activate"
                        onClicked: if (!profRow.modelData.active) Net.activateProfile(profRow.modelData.name)
                    }
                }
            }
        }
    }
}
