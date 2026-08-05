// Audio settings: output/input volume + mute + device switching, and an app-volumes sub-page.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
            title: "Audio"

            SectionHeader { first: true; text: "Output" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                SliderRow {
                    first: true; last: false
                    icon: Audio.muted ? "volume_off" : (Audio.volume < 0.5 ? "volume_down" : "volume_up")
                    label: "Volume"; value: Audio.volume
                    onMoved: v => Audio.setVolume(v)
                }
                ToggleRow {
                    first: false; last: false
                    text: "Muted"; checked: Audio.muted; onToggled: Audio.toggleMute()
                }
                AudioDeviceList {
                    first: false
                    nodes: Audio.sinks; currentId: Audio.sink?.id ?? -1; iconName: "speaker"
                    placeholderIcon: "speaker"; placeholderText: "No output devices"
                    onSelected: node => Audio.setAudioSink(node)
                }
            }

            SectionHeader { text: "Input" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                SliderRow {
                    first: true; last: false
                    icon: Audio.sourceMuted ? "mic_off" : "mic"
                    label: "Volume"; value: Audio.sourceVolume
                    onMoved: v => Audio.setSourceVolume(v)
                }
                ToggleRow {
                    first: false; last: false
                    text: "Muted"; checked: Audio.sourceMuted; onToggled: Audio.toggleMic()
                }
                AudioDeviceList {
                    first: false
                    nodes: Audio.sources; currentId: Audio.source?.id ?? -1; iconName: "mic"
                    placeholderIcon: "mic_off"; placeholderText: "No input devices"
                    onSelected: node => Audio.setAudioSource(node)
                }
            }

            SectionHeader { text: "Applications" }
            NavRow {
                first: true; last: true
                icon: "tune"; label: "App volumes"
                status: Audio.streams.length === 0 ? "No apps playing audio"
                        : Audio.streams.length === 1 ? "1 app playing audio"
                        : Audio.streams.length + " apps playing audio"
                onClicked: stack.push(appPage)
            }
        }
    }

    Component {
        id: appPage
        PageBase {
            title: "App volumes"
            isSubPage: true
            onBack: stack.pop()
            ItemList {
                Layout.fillHeight: true
                placeholderIcon: "music_off"
                placeholderText: "No apps playing audio"
                model: Audio.streams
                delegate: Item {
                    id: strm
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: 58
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 16
                        anchors.topMargin: 8; anchors.bottomMargin: 10
                        spacing: 4
                        Text {
                            text: Audio.getStreamName(strm.modelData); color: Config.fg
                            font.family: Config.textFont; font.pixelSize: 12
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        HSlider {
                            value: strm.modelData?.audio?.volume ?? 0
                            onMoved: v => Audio.setStreamVolume(strm.modelData, v)
                        }
                    }
                }
            }
        }
    }
}
