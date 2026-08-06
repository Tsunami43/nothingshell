// Material Symbols icon.
pragma ComponentBehavior: Bound

import QtQuick
import qs
Text {
    font.family: Config.iconFont
    font.pixelSize: 16
    color: Config.fg
    horizontalAlignment: Text.AlignHCenter
    // The text here is a glyph name, so a screen reader would read out the font's internals.
    Accessible.ignored: true
    Behavior on color { ColorAnim {} }
}
