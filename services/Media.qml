pragma Singleton

// Active MPRIS player (first one that can play) + a "now playing" OSD trigger.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property MprisPlayer player: (Mpris.players?.values ?? []).find(p => p.canPlay) ?? null

    readonly property string trackTitle: player?.trackTitle ?? ""
    onTrackTitleChanged: {
        if (trackTitle.length > 0)
            Osd.showMedia();
        Qt.callLater(_sync);
    }

    // Cover art and track length, held for as long as the track lasts. Firefox publishes
    // mpris:artUrl and mpris:length for a couple of seconds, then drops both keys mid-track,
    // so binding straight through blinks the cover to the placeholder and the duration to
    // 0:00. Quickshell also flips lengthSupported off at that point and `length` starts
    // returning fractions of a second, which would peg the progress bar at full.
    readonly property string rawArt: player?.trackArtUrl ?? ""
    readonly property real rawLength: (player?.lengthSupported ?? false) ? (player?.length ?? 0) : 0

    property string artUrl: ""
    property real trackLength: 0
    property string _heldFor: ""    // track the held values belong to

    // Same Metadata update as trackTitle, in no guaranteed signal order — reconcile once
    // after it settles.
    onRawArtChanged: Qt.callLater(_sync)
    onRawLengthChanged: Qt.callLater(_sync)

    function _sync() {
        if (_heldFor !== trackTitle) {      // new track — drop the previous one's values
            artUrl = "";
            trackLength = 0;
            _heldFor = trackTitle;
        }
        if (rawArt !== "")
            artUrl = rawArt;
        if (rawLength > 0)
            trackLength = rawLength;
    }

    function playPause() { player?.togglePlaying(); }
    function next()      { player?.next(); }
    function previous()  { player?.previous(); }
}
