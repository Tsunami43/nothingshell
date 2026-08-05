// Looping, silent video layer for live wallpaper / lock background (QtMultimedia).
import QtQuick
import QtMultimedia

Item {
    id: root
    property string file: ""        // absolute path to the video
    // Set false by whoever knows the layer cannot be seen. Nothing in Wayland tells a background
    // surface it is occluded, so without this the h264 decoder runs flat out behind a full-screen
    // window — a whole thread pool decoding frames nobody will ever be shown.
    property bool active: true
    readonly property bool ready: player.playbackState === MediaPlayer.PlayingState

    readonly property bool shouldPlay: root.visible && root.active && root.file !== ""

    MediaPlayer {
        id: player
        source: root.file ? "file://" + root.file : ""
        loops: MediaPlayer.Infinite
        // Bound, not a constant: autoPlay is what starts a source once it has finished loading, and
        // a play() issued before then is dropped on the floor. Binding it to shouldPlay means a
        // source that loads while the wallpaper is hidden simply never starts.
        autoPlay: root.shouldPlay
        videoOutput: vo
        // no audioOutput -> silent
    }
    VideoOutput {
        id: vo
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
    // Pause rather than stop: the decoder keeps its position, so coming back is a resume and not
    // a seek to zero with a black frame in between. autoPlay above covers the load-time case.
    onShouldPlayChanged: root.shouldPlay ? player.play() : player.pause()
}
