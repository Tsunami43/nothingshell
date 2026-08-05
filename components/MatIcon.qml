// Material Symbols icon.
pragma ComponentBehavior: Bound

import QtQuick
import qs
Text {
    font.family: Config.iconFont
    font.pixelSize: 16
    color: Config.fg
    horizontalAlignment: Text.AlignHCenter
    Behavior on color { ColorAnim {} }
}
