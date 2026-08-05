pragma Singleton

// Default audio sink/source (volume, mute, mic) + full device/stream enumeration and
// default-device switching for the Settings audio page. Fires a volume OSD on change.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // --- Default sink/source (bar + OSD) ---
    readonly property PwNode sink:   Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume:       sink?.audio?.volume ?? 0
    readonly property bool muted:        !!sink?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0
    readonly property bool sourceMuted:  !!source?.audio?.muted
    readonly property bool micMuted:      sourceMuted   // legacy alias

    function setVolume(v) {
        if (sink?.ready && sink?.audio) { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1, v)); }
    }
    function addVolume(d) { setVolume(volume + d); }
    function toggleMute()  { if (sink?.audio) sink.audio.muted = !sink.audio.muted; }
    function toggleMic()   { if (source?.audio) source.audio.muted = !source.audio.muted; }

    function setSourceVolume(v) {
        if (source?.ready && source?.audio) { source.audio.muted = false; source.audio.volume = Math.max(0, Math.min(1, v)); }
    }

    onVolumeChanged: Osd.show("volume")
    onMutedChanged:  Osd.show("volume")

    // --- Device / stream enumeration (Settings) ---
    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    property list<PwNode> streams: []
    // Playback streams only — what the dashboard mixer offers a slider for. Capture streams
    // (a call app listening on the mic) are excluded by class; anything unlabelled is kept,
    // since a missing media.class is likelier to be a player than a recorder.
    readonly property var playbackStreams:
        streams.filter(s => !(s.properties["media.class"] ?? "").startsWith("Stream/Input"))

    function setAudioSink(node)   { Pipewire.preferredDefaultAudioSink = node; }
    function setAudioSource(node) { Pipewire.preferredDefaultAudioSource = node; }

    function setStreamVolume(stream, v) {
        if (stream?.ready && stream?.audio) { stream.audio.muted = false; stream.audio.volume = Math.max(0, Math.min(1, v)); }
    }
    function setStreamMuted(stream, m) { if (stream?.ready && stream?.audio) stream.audio.muted = m; }
    function getStreamName(stream) {
        if (!stream)
            return "Unknown";
        return stream.properties["application.name"] || stream.description || stream.name || "Unknown";
    }

    function refreshNodes() {
        const newSinks = [];
        const newSources = [];
        const newStreams = [];
        for (const node of Pipewire.nodes.values) {
            if (!node.isStream) {
                if (node.isSink)
                    newSinks.push(node);
                else if (node.audio)
                    newSources.push(node);
            } else if (node.audio) {
                newStreams.push(node);
            }
        }
        root.sinks = newSinks;
        root.sources = newSources;
        root.streams = newStreams;
    }

    // Pipewire.nodes may already be populated when this lazily-created singleton loads,
    // so refresh once immediately and then whenever the node set changes.
    Component.onCompleted: refreshNodes()
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root.refreshNodes(); }
    }

    // Track defaults + every listed node so their volume/mute stay live.
    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.sources, ...root.streams].filter(n => n)
    }
}
