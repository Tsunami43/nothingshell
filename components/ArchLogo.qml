// Arch logo as vector geometry, not a Nerd Font codepoint. It was the shell's only glyph outside
// the bundled faces, so drawing it here is what lets the whole Nerd Font dependency go away —
// everything else already comes out of assets/fonts.
//
// Path is the official mark as shipped in archlinux-logo (the trademark text beside it is not
// reproduced). It is authored in a 256x256 box with the glyph inset 12 on every side, so the item
// keeps ~9% padding at any size and stays square; anything non-square centres inside the shorter
// edge. Fill rule is odd-even: the hole under the peak is part of the same subpath.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: root
    property color color: Config.accent

    implicitWidth: 22
    implicitHeight: 22

    Shape {
        anchors.centerIn: parent
        width: 256
        height: 256
        // Scaled rather than sized: PathSvg takes absolute coordinates, so the geometry is fixed at
        // its authored box and the transform does the fitting.
        scale: Math.min(root.width, root.height) / 256
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            PathSvg { path: "m127.98 12.07c-10.316 25.309-16.543 41.855-28.031 66.41 7.043 7.4609 15.691 16.156 29.734 25.977-15.098-6.207-25.395-12.445-33.094-18.918-14.703 30.68-37.742 74.391-84.492 158.39 36.746-21.219 65.23-34.293 91.773-39.289-1.1406-4.8945-1.7852-10.195-1.7422-15.734l0.042969-1.1719c0.58203-23.551 12.828-41.645 27.336-40.418 14.508 1.2266 25.781 21.316 25.199 44.867-0.10938 4.4219-0.60938 8.6914-1.4805 12.641 26.258 5.1328 54.438 18.18 90.684 39.105-7.1484-13.156-13.527-25.016-19.621-36.316-9.5938-7.4336-19.605-17.117-40.023-27.594 14.035 3.6406 24.082 7.8516 31.914 12.555-61.941-115.32-66.957-130.66-88.199-180.5z" }
        }
    }

    Behavior on color { ColorAnim {} }
}
