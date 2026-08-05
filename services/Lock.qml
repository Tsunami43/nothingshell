pragma Singleton

// Screen-lock state + PAM authentication.
import QtQuick
import Quickshell
import Quickshell.Services.Pam

Singleton {
    id: root

    property bool locked: false
    property string password: ""
    property string error: ""
    property bool busy: false

    PamContext {
        id: pam
        config: "login"
        onResponseRequiredChanged: {
            if (responseRequired) pam.respond(root.password);
        }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.locked = false;
                root.password = "";
                root.error = "";
            } else {
                root.error = (result === PamResult.MaxTries) ? "Too many attempts" : "Incorrect password";
                root.password = "";
            }
        }
    }
    function submit() {
        if (pam.active || root.password.length === 0) return;
        root.error = "";
        // A failed start emits no `completed`, so taking `busy` on faith would disable the password
        // field for the rest of the lock — with no way to type and no way out.
        if (!pam.start()) {
            root.error = "Authentication unavailable";
            root.password = "";
            return;
        }
        root.busy = true;
    }
}
