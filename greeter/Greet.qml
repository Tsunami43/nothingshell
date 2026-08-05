pragma Singleton

// greetd login state: one fixed account, a password prompt and the session launch.
// Mirrors services/Lock.qml of the main shell, but talks to greetd instead of PAM
// (the greeter runs as the `greeter` user and cannot authenticate through PAM itself).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs

Singleton {
    id: root

    // Which account to log in and what to start for it. Machine-specific by definition, so it is
    // read from greeter.json beside this file rather than written into the code — install.sh
    // generates that file, taking the user it was sudo'd from and the Exec line of the installed
    // wayland session. greeter.json.example documents the shape.
    property string user: ""
    property var command: []
    property var environment: ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=Hyprland"]
    // Set once the file has been read, so the UI can say what is wrong instead of failing to log
    // in with no explanation.
    property bool configured: false

    FileView {
        id: conf
        path: Qt.resolvedUrl("greeter.json").toString().replace("file://", "")
        printErrors: false
        onLoaded: {
            try {
                const c = JSON.parse(conf.text());
                root.user = c.user ?? "";
                root.command = c.command ?? [];
                if (Array.isArray(c.environment)) root.environment = c.environment;
                if (c.theme) Config.activeTheme = c.theme;
                root.configured = root.user !== "" && root.command.length > 0;
                if (!root.configured) root.error = "greeter.json is missing `user` or `command`";
            } catch (e) {
                root.error = "greeter.json is not valid JSON";
            }
        }
        onLoadFailed: root.error = "no greeter.json beside the greeter — run install.sh"
    }

    property string password: ""
    property string error: ""
    // True outside a greetd session (running under a normal user for a UI preview).
    readonly property bool available: Greetd.available
    readonly property bool busy: Greetd.state === GreetdState.Authenticating
    readonly property bool launching: Greetd.state === GreetdState.ReadyToLaunch
                                   || Greetd.state === GreetdState.Launching
                                   || Greetd.state === GreetdState.Launched

    function submit() {
        if (root.busy || root.launching || root.password.length === 0)
            return;
        if (!root.configured) {
            // The error text is already whatever the config reader put there.
            if (root.error === "") root.error = "greeter is not configured";
            return;
        }
        if (!Greetd.available) {
            root.error = "greetd unavailable (preview mode)";
            return;
        }
        root.error = "";
        Greetd.createSession(root.user);
    }

    function fail(message) {
        root.error = message;
        root.password = "";
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
    }

    Connections {
        target: Greetd

        // A hidden prompt is the password prompt, and gets the typed password. A prompt that
        // ECHOES is asking for something else — an OTP, a username, a PAM plugin's question —
        // and answering it with the password would put it on screen and into greetd's log.
        // It is answered empty and the question is shown, so at least it is visible why the
        // login stalled. Info and error messages carry no prompt but still need an empty
        // response, otherwise the exchange never advances.
        function onAuthMessage(message, isError, responseRequired, echoResponse) {
            if (responseRequired && !echoResponse) {
                Greetd.respond(root.password);
                return;
            }
            if (responseRequired && message)
                root.error = message;
            Greetd.respond("");
        }
        // Authentication passed: start the session and quit the greeter.
        function onReadyToLaunch() {
            Greetd.launch(root.command, root.environment, true);
        }
        function onAuthFailure(message) { root.fail(message || "Incorrect password"); }
        function onError(message) { root.fail(message || "Login failed"); }
    }
}
