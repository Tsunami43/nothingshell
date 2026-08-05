// Image that cross-fades when its source changes (album art, etc.).
pragma ComponentBehavior: Bound

import QtQuick
Item {
    id: fade
    property string source: ""
    property int fillMode: Image.PreserveAspectCrop
    // Painted size in logical pixels; the decode size is derived from it.
    property int box: 96

    // Decode at physical resolution, and only ever grow: Qt keys its pixmap cache on
    // (url, sourceSize), so shrinking re-reads a source that may already be gone (Firefox
    // drops its art in /tmp and deletes it) and blinks the cover out. devicePixelRatio
    // reads 1 until the item has a screen, which is when a naive binding would do that.
    property int _decode: 1
    function _grow() {
        const d = Math.ceil(box * Math.max(1, Screen.devicePixelRatio));
        if (d > _decode)
            _decode = d;
    }
    Component.onCompleted: _grow()
    onBoxChanged: _grow()
    Connections {
        target: fade.Screen
        function onDevicePixelRatioChanged() { fade._grow(); }
    }

    // Which slot is on screen. The other one is free to load the next source behind it.
    property bool _showB: false
    property string _sa: ""
    property string _sb: ""

    // "This slot holds a usable frame." Cleared only when the slot is handed a different
    // source, not on a failed reload of the same URL — retainWhileLoading keeps that frame up.
    property bool _okA: false
    property bool _okB: false

    // Only the visible slot counts, or a stale hidden image would keep `ready` true after
    // switching to a track with no art.
    readonly property bool ready: _showB ? _okB : _okA

    onSourceChanged: {
        if (source === (_showB ? _sb : _sa))
            return;                              // already the visible one
        if (source === "") {
            // Nothing to load — flip to the empty slot so the old art fades out.
            if (_showB) { _sa = ""; _okA = false; } else { _sb = ""; _okB = false; }
            _showB = !_showB;
            return;
        }
        // Load behind the visible slot. Re-selecting a URL the slot already holds emits no
        // status change, so don't drop its flag — and call _settled() by hand to hand over.
        if (_showB) { if (_sa !== source) _okA = false; _sa = source; }
        else        { if (_sb !== source) _okB = false; _sb = source; }
        _settled(!_showB);
    }

    // Hand over only once the incoming image has decoded, or the swap reads as a blink.
    // Errors flip too, so a broken URL falls through to the caller's placeholder. Compares
    // the slot string, not Image.source — Qt resolves that to an absolute URL and it never
    // matches.
    function _settled(slotIsB) {
        if (fade._showB === slotIsB || (slotIsB ? _sb : _sa) !== fade.source)
            return;
        const st = slotIsB ? imgB.status : imgA.status;
        if (st === Image.Ready) {
            // Also set here, not just in onStatusChanged: a slot that already held this URL
            // hands over silently, and a down flag would draw the placeholder over a good frame.
            if (slotIsB) fade._okB = true; else fade._okA = true;
            fade._showB = slotIsB;
        } else if (st === Image.Error) {
            // Hand over to an EMPTY slot: retainWhileLoading would otherwise leave an older
            // source's frame under the placeholder.
            if (slotIsB) { _sb = ""; _okB = false; } else { _sa = ""; _okA = false; }
            fade._showB = slotIsB;
        }
    }

    Image {
        id: imgA
        anchors.fill: parent; source: fade._sa; fillMode: fade.fillMode
        asynchronous: true; cache: true; retainWhileLoading: true
        sourceSize: Qt.size(fade._decode, fade._decode)
        opacity: fade._showB ? 0 : 1
        onStatusChanged: {
            if (status === Image.Ready)
                fade._okA = true;
            fade._settled(false);
        }
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
    }
    Image {
        id: imgB
        anchors.fill: parent; source: fade._sb; fillMode: fade.fillMode
        asynchronous: true; cache: true; retainWhileLoading: true
        sourceSize: Qt.size(fade._decode, fade._decode)
        opacity: fade._showB ? 1 : 0
        onStatusChanged: {
            if (status === Image.Ready)
                fade._okB = true;
            fade._settled(true);
        }
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
    }
}
