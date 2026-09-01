import QtQuick

QtObject {
    function connect(secret) {
        Quickshell.execDetached(["nmcli", "device", "wifi", "connect", "ssid", "password", secret]);
    }
}
