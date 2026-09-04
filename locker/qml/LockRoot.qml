import QtQuick
import Quickshell
import Quickshell.Wayland
import Sleepy.Locker.Native

Scope {
    id: root

    property bool lockRequested: false
    readonly property bool secure: sessionLock.secure

    LockerEndpoint {
        id: endpoint
        secure: sessionLock.secure
        onLockRequested: root.lockRequested = true
    }

    function requestLock(): void {
        root.lockRequested = true;
    }

    WlSessionLock {
        id: sessionLock
        objectName: "sleepySessionLock"
        locked: root.lockRequested

        // WlSessionLock owns one instance of this component for every current
        // output and repeats the same lifecycle for monitor hotplug.
        WlSessionLockSurface {
            id: lockSurface
            color: "#111318"

            // The surface delegate is created only when a lock is requested.
            // Component completion can therefore run before its Wayland window
            // is visible and able to accept keyboard focus. Reacquire focus
            // after the compositor maps each output's secure surface.
            onVisibleChanged: {
                if (visible)
                    Qt.callLater(() => prompt.forceActiveFocus());
            }

            SecurePrompt {
                id: prompt
                objectName: "securePrompt"
                anchors.fill: parent
                focus: true
                activeFocusOnTab: true
                Accessible.role: Accessible.EditableText
                Accessible.name: qsTr("Password")
                Accessible.passwordEdit: true
                Accessible.description: qsTr("Native secure password input")

                Component.onCompleted: forceActiveFocus()
                onAuthenticated: {
                    // The native successful PAM result is the sole trigger for
                    // the protocol's unlock-and-destroy request.
                    if (sessionLock.secure && endpoint.unlockAllowed)
                        sessionLock.unlock();
                }

                SleepyLockView {
                    anchors.fill: parent
                    inputLength: prompt.inputLength
                    authState: prompt.authState
                    outputSize: Qt.size(lockSurface.width, lockSurface.height)
                    onAuthenticateRequested: prompt.authenticate()
                }
            }
        }

        onLockedChanged: {
            if (!locked)
                root.lockRequested = false;
        }
    }
}
