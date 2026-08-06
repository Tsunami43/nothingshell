// About: what this machine and this shell actually are. Everything is collected by one shell
// script on page load rather than by a poller — none of it changes while the page is open, and
// the page is destroyed the moment you navigate away.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.settings.common
StackView {
    id: stack
    clip: true
    initialItem: mainPage

    // key -> value, filled in by infoProc below.
    property var info: ({})
    function get(k, fallback) { return stack.info[k] || (fallback ?? "—"); }

    Process {
        id: infoProc
        running: true
        // One process, tab-separated key/value lines. Every lookup is guarded so a missing tool
        // (lspci is not installed everywhere) leaves a blank row instead of failing the batch.
        command: ["sh", "-c", `
            . /etc/os-release 2>/dev/null
            printf 'distro\t%s\n' "\${PRETTY_NAME:-unknown}"
            printf 'kernel\t%s\n' "$(uname -r)"
            printf 'arch\t%s\n' "$(uname -m)"
            printf 'host\t%s\n' "$(uname -n)"
            printf 'uptime\t%s\n' "$(uptime -p 2>/dev/null | sed 's/^up //')"
            printf 'cpu\t%s\n' "$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)"
            printf 'cores\t%s\n' "$(nproc)"
            printf 'ram\t%s GiB\n' "$(awk '/MemTotal/{printf "%.1f", $2/1048576}' /proc/meminfo)"
            printf 'gpu\t%s\n' "$(lspci 2>/dev/null | grep -iE 'vga|3d controller' | head -1 | sed 's/.*: //')"
            printf 'hyprland\t%s\n' "$(hyprctl version 2>/dev/null | head -1 | sed 's/^Hyprland //; s/ built.*//')"
            printf 'quickshell\t%s\n' "$(qs --version 2>/dev/null | head -1 | awk '{printf "%s (%s)", $2, substr($4, 1, 7)}')"
            printf 'compositor\t%s\n' "\${XDG_CURRENT_DESKTOP:-unknown}"
            printf 'session\t%s\n' "\${XDG_SESSION_TYPE:-unknown}"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("\t");
                    if (i > 0) out[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                stack.info = out;
            }
        }
    }

    Component {
        id: mainPage
        PageBase {
            title: "About"

            SectionHeader { first: true; text: "System" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                InfoRow { first: true;  last: false; icon: "computer";  label: "Distribution"; value: stack.get("distro") }
                InfoRow { first: false; last: false; icon: "memory";    label: "Kernel"; value: stack.get("kernel") + " (" + stack.get("arch") + ")" }
                InfoRow { first: false; last: false; icon: "dns";       label: "Hostname"; value: stack.get("host") }
                InfoRow { first: false; last: true;  icon: "schedule";  label: "Uptime"; value: stack.get("uptime") }
            }

            SectionHeader { text: "Hardware" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                InfoRow { first: true;  last: false; icon: "developer_board"; label: "Processor"
                          value: stack.get("cpu") + (stack.info.cores ? " × " + stack.info.cores : "") }
                InfoRow { first: false; last: false; icon: "memory"; label: "Memory"; value: stack.get("ram") }
                InfoRow { first: false; last: false; visible: !!stack.info.gpu
                          icon: "monitor"; label: "Graphics"; value: stack.get("gpu") }
                InfoRow { first: false; last: true;  icon: "desktop_windows"; label: "Displays"
                          value: Display.monitors.length + (Display.monitors.length === 1 ? " output" : " outputs") }
            }

            SectionHeader { text: "Shell" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                InfoRow { first: true;  last: false; icon: "terminal"; label: "Quickshell"; value: stack.get("quickshell") }
                InfoRow { first: false; last: false; icon: "widgets";  label: "Compositor"
                          value: stack.get("compositor") + " " + stack.get("hyprland", "") }
                InfoRow { first: false; last: false; icon: "layers";   label: "Session"; value: stack.get("session") }
                InfoRow { first: false; last: false; icon: "folder";   label: "Shell tree"; value: Paths.shellDir }
                InfoRow { first: false; last: true;  icon: "settings"; label: "Settings file"; value: Paths.settingsFile }
            }

            SectionHeader { text: "Actions" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ButtonRow {
                    first: true; last: false
                    icon: "content_copy"; label: "Copy system information"
                    onClicked: {
                        const lines = [];
                        for (const k in stack.info) lines.push(k + ": " + stack.info[k]);
                        Quickshell.execDetached(["wl-copy", lines.join("\n")]);
                    }
                }
                ButtonRow {
                    first: false; last: true
                    icon: "refresh"; label: "Reload the shell"
                    subtext: "Re-reads every QML file; window positions and popouts reset"
                    onClicked: Quickshell.reload(false)
                }
            }
        }
    }
}
