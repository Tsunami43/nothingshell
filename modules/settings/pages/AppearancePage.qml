// Appearance: where the palette comes from (wallpaper-derived Material You vs a curated preset),
// the theme itself, the static wallpaper, the text face and the global animation speed — all of
// it spelled out, where the old Quick page hid it behind two unlabelled icon buttons.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import qs
import qs.services
import qs.components
import qs.modules.settings.common
StackView {
    id: stack
    clip: true
    initialItem: mainPage

    // matugen's scheme algorithms — how far the palette is allowed to drift from the wallpaper's
    // own colours. Only meaningful while autoColors is on.
    readonly property var schemes: [
        { value: "scheme-tonal-spot", label: "Tonal spot", subtext: "Balanced (default)" },
        { value: "scheme-content", label: "Content", subtext: "Closest to the image" },
        { value: "scheme-fidelity", label: "Fidelity", subtext: "Faithful hues" },
        { value: "scheme-vibrant", label: "Vibrant", subtext: "Saturated" },
        { value: "scheme-expressive", label: "Expressive", subtext: "Shifted hues" },
        { value: "scheme-fruit-salad", label: "Fruit salad", subtext: "Playful" },
        { value: "scheme-rainbow", label: "Rainbow" },
        { value: "scheme-neutral", label: "Neutral", subtext: "Desaturated" },
        { value: "scheme-monochrome", label: "Monochrome", subtext: "Greyscale" }
    ]

    Component {
        id: mainPage
        PageBase {
            title: "Appearance"

            SectionHeader { first: true; text: "Colours" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ToggleRow {
                    first: true; last: false
                    text: "Auto colours"
                    subtext: "Derive the whole palette from the wallpaper (Material You)"
                    checked: Config.autoColors
                    onToggled: Config.autoColors = !Config.autoColors
                }
                ToggleRow {
                    first: false; last: false
                    // Only auto mode has a choice to make: a curated preset carries its own
                    // light/dark flag, and overriding it would break its hand-picked palette.
                    visible: Config.autoColors
                    text: "Light mode"
                    subtext: "Use the light scheme from the generated palette"
                    checked: Config.autoLight
                    onToggled: Config.autoLight = !Config.autoLight
                }
                SelectRow {
                    first: false; last: false
                    visible: Config.autoColors
                    label: "Scheme type"
                    subtext: "How far the palette may drift from the image"
                    options: stack.schemes
                    value: Config.schemeType
                    onSelected: v => { Config.schemeType = v; Wallpaper.regenTheme(); }
                }
                ButtonRow {
                    first: false; last: true
                    icon: "auto_awesome"
                    label: "Regenerate palette"
                    subtext: "Re-run matugen on the current wallpaper"
                    onClicked: Wallpaper.regenTheme()
                }
            }

            SectionHeader { text: "Theme" }
            ConnectedRect {
                Layout.fillWidth: true
                implicitHeight: themeFlow.implicitHeight + 24
                // Dimmed, not hidden, while auto colours own the palette: the preset still picks
                // the video wallpaper, so it is not inert — just not driving the colours.
                opacity: Config.autoColors ? 0.5 : 1
                Behavior on opacity { Effect {} }

                GridLayout {
                    id: themeFlow
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    columns: 4
                    rowSpacing: 10
                    columnSpacing: 10

                    Repeater {
                        model: Themes.order
                        delegate: Item {
                            id: card
                            required property string modelData
                            readonly property var t: Themes.map[card.modelData]
                            readonly property bool current: Config.activeTheme === card.modelData
                            Layout.fillWidth: true
                            implicitHeight: width * 0.62 + 22

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 4
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + Themes.dir + "thumbs/" + card.modelData + ".jpg"
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize: Qt.size(360, 220)
                                        asynchronous: true; cache: true
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: cardMask
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1.0
                                        }
                                    }
                                    Item {
                                        id: cardMask
                                        anchors.fill: parent
                                        layer.enabled: true
                                        visible: false
                                        Rectangle { anchors.fill: parent; radius: 12 }
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 12; color: "transparent"
                                        border.width: card.current ? 2 : 1
                                        border.color: card.current ? Config.accent : Config.outlineVariant
                                        Behavior on border.color { ColorAnim {} }
                                    }
                                    StateLayer {
                                        ovRadius: 12
                                        // Picking a preset means opting out of wallpaper colours —
                                        // otherwise the click would visibly do nothing.
                                        onTapped: { Config.autoColors = false; Config.activeTheme = card.modelData; }
                                    }
                                }
                                Text {
                                    text: card.t?.title ?? card.modelData
                                    color: card.current ? Config.accent : Config.dim
                                    font.family: Config.textFont; font.pixelSize: 11
                                    font.bold: card.current
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            SectionHeader { text: "Wallpaper" }
            NavRow {
                first: true; last: true
                icon: "wallpaper"
                label: "Static wallpaper"
                status: {
                    const p = (Config.wallpaper || "").replace("file://", "");
                    return p ? p.split("/").pop() : "None";
                }
                onClicked: stack.push(wallPage)
            }

            SectionHeader { text: "Text" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                SelectRow {
                    first: true; last: false
                    label: "Text face"
                    subtext: "Any .ttf/.otf dropped into assets/fonts shows up here"
                    options: Config.fontFiles.map(f => ({ value: f.key, label: f.label }))
                    value: Config.fontKey
                    // Each choice previews in its own face — the point of picking one.
                    optionFont: o => Config.fontNames[o.value] ?? Config.textFont
                    onSelected: v => Config.fontPreset = v
                }
                InfoRow {
                    first: false; last: true
                    icon: "abc"; label: "Preview"; value: "The quick brown fox 0123"
                }
            }

            SectionHeader { text: "Motion" }
            SliderRow {
                first: true; last: true
                icon: "speed"
                label: "Animation speed"
                // Stored as a duration multiplier, shown as speed, so dragging right feels faster.
                value: (2.0 - Config.motionScale) / 1.75
                valueText: Config.motionScale === 1 ? "Normal" : (1 / Config.motionScale).toFixed(2) + "×"
                onMoved: v => Config.motionScale = Math.round((2.0 - v * 1.75) * 20) / 20
            }
        }
    }

    Component {
        id: wallPage
        PageBase {
            title: "Wallpaper"
            isSubPage: true
            onBack: stack.pop()

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: "Images from ~/Pictures/wallpapers. Picking one copies it into place and "
                      + "regenerates the Material palette from it."
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            ConnectedRect {
                Layout.fillWidth: true
                visible: Wallpaper.list.length > 0
                implicitHeight: wallGrid.implicitHeight + 24
                GridLayout {
                    id: wallGrid
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12
                    columns: 3
                    rowSpacing: 10; columnSpacing: 10
                    Repeater {
                        model: Wallpaper.list
                        delegate: Item {
                            id: wall
                            required property string modelData
                            readonly property bool current: (Config.wallpaper || "").replace("file://", "") === wall.modelData
                            Layout.fillWidth: true
                            implicitHeight: width * 0.6
                            Image {
                                anchors.fill: parent
                                source: "file://" + wall.modelData
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(420, 260)
                                asynchronous: true; cache: true
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: wallMask
                                    maskThresholdMin: 0.5
                                    maskSpreadAtMin: 1.0
                                }
                            }
                            Item {
                                id: wallMask
                                anchors.fill: parent
                                layer.enabled: true
                                visible: false
                                Rectangle { anchors.fill: parent; radius: 12 }
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 12; color: "transparent"
                                border.width: wall.current ? 2 : 1
                                border.color: wall.current ? Config.accent : Config.outlineVariant
                            }
                            StateLayer { ovRadius: 12; onTapped: Wallpaper.set(wall.modelData) }
                        }
                    }
                }
            }

            ConnectedRect {
                Layout.fillWidth: true
                visible: Wallpaper.list.length === 0
                implicitHeight: 96
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    MatIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "image_not_supported"; color: Config.dim; font.pixelSize: 28
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No images in ~/Pictures/wallpapers"
                        color: Config.dim; font.family: Config.textFont; font.pixelSize: 12
                    }
                }
            }
        }
    }
}
