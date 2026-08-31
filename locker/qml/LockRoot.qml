import QtQuick
import Quickshell
import Quickshell.Wayland
import Sleepy.Locker

Scope {
    id: root

    property bool lockRequested: false
    readonly property bool secure: sessionLock.secure

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
                    if (sessionLock.secure)
                        sessionLock.unlock();
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 420)
                    height: 196
                    radius: 28
                    color: "#20242b"
                    border.color: "#5f6b7a"

                    Column {
                        anchors.centerIn: parent
                        spacing: 22

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "#f1f3f5"
                            font.pixelSize: 25
                            text: qsTr("Sleepy is locked")
                            textFormat: Text.PlainText
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "#ccd3dc"
                            font.pixelSize: 22
                            text: "●".repeat(prompt.inputLength)
                            textFormat: Text.PlainText
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: prompt.authState === AuthState.Rejected ? "#ffb4ab" : "#bac2cf"
                            font.pixelSize: 15
                            text: prompt.authState === AuthState.Authenticating ? qsTr("Checking…")
                                : prompt.authState === AuthState.Rejected ? qsTr("Authentication failed")
                                : qsTr("Type your password and press Enter")
                            textFormat: Text.PlainText
                        }
                    }
                }
            }
        }

        onLockedChanged: {
            if (!locked)
                root.lockRequested = false;
        }
    }
}
