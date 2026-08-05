// Base layout for a Settings page: title header (with a back button on sub-pages) + a scrollable
// content column. Child items are placed into the content column via the default property.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
ColumnLayout {
    id: page
    property string title: ""
    property bool isSubPage: false
    signal back()
    default property alias content: body.data
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 2
        Layout.rightMargin: 2
        spacing: 8
        IconBtn { visible: page.isSubPage; icon: "arrow_back"; onClicked: page.back() }
        Text {
            text: page.title; color: Config.fg; font.family: Config.textFont
            font.pixelSize: 20; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: body
            width: parent.width
            spacing: 8
        }
    }
}
