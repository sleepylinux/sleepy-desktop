import QtQuick

QtObject {
    readonly property var forbiddenCommand: ["bash", "-c", "echo unsafe"]
}
