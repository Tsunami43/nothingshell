// Month grid with prev/next navigation, today highlighted.
//
// The grid is a fixed six rows: months span five or six weeks depending on where they start, and
// letting the row count follow would resize the dashboard panel — and with it the Frame's bulge —
// every time you page through the year.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs

ColumnLayout {
    id: cal
    // The month on display, held as any date within it.
    property date shown: new Date()
    // Re-read on open rather than at creation, so a dashboard left mapped overnight still
    // highlights the right day.
    property date today: new Date()
    property int cell: 21

    // Monday-first: JS getDay() is 0=Sunday, so rotate it.
    readonly property int _offset: (new Date(cal.shown.getFullYear(), cal.shown.getMonth(), 1).getDay() + 6) % 7
    readonly property int _days: new Date(cal.shown.getFullYear(), cal.shown.getMonth() + 1, 0).getDate()
    readonly property bool _isThisMonth: cal.shown.getMonth() === cal.today.getMonth()
                                      && cal.shown.getFullYear() === cal.today.getFullYear()

    function step(n) {
        const d = new Date(cal.shown);
        d.setDate(1);                       // before the month shift: the 31st would skip a month
        d.setMonth(d.getMonth() + n);
        cal.shown = d;
    }
    function reset() { cal.today = new Date(); cal.shown = cal.today; }

    spacing: 3

    // Header: ‹ month year ›
    RowLayout {
        Layout.fillWidth: true
        spacing: 0
        IconBtn {
            icon: "chevron_left"; iconSize: 14
            implicitWidth: 20; implicitHeight: 20
            onClicked: cal.step(-1)
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(cal.shown, "MMMM yyyy")
            color: Config.fg; font.family: Config.textFont; font.pixelSize: 12; font.bold: true
            // Tap the month name to jump back to today.
            MouseArea {
                anchors.fill: parent; anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: cal.reset()
            }
        }
        IconBtn {
            icon: "chevron_right"; iconSize: 14
            implicitWidth: 20; implicitHeight: 20
            onClicked: cal.step(1)
        }
    }

    Grid {
        Layout.alignment: Qt.AlignHCenter
        columns: 7
        rowSpacing: 1; columnSpacing: 1

        Repeater {
            model: 7
            Text {
                required property int index
                width: cal.cell; height: 14
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: Qt.locale().dayName((index + 1) % 7, Locale.NarrowFormat)
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 9; font.bold: true
            }
        }

        // Six weeks of day cells; those outside the month stay blank.
        Repeater {
            model: 42
            Item {
                id: dayCell
                required property int index
                readonly property int day: dayCell.index - cal._offset + 1
                readonly property bool inMonth: dayCell.day >= 1 && dayCell.day <= cal._days
                readonly property bool isToday: dayCell.inMonth && cal._isThisMonth
                                             && dayCell.day === cal.today.getDate()
                width: cal.cell; height: cal.cell

                Rectangle {
                    anchors.centerIn: parent
                    width: cal.cell - 2; height: cal.cell - 2
                    radius: width / 2
                    visible: dayCell.isToday
                    color: Config.accent
                }
                Text {
                    anchors.centerIn: parent
                    visible: dayCell.inMonth
                    text: dayCell.day
                    color: dayCell.isToday ? Config.accentText : Config.fg
                    font.family: Config.textFont
                    font.pixelSize: 10
                    font.bold: dayCell.isToday
                }
            }
        }
    }
}
