pragma ComponentBehavior: Bound

import QtQuick 6.0
import "../widgets" as Widgets
import "../services" as Services

FocusScope {
    id: root
    required property var presetAdapter
    required property string presetId
    required property string presetName
    required property var colors
    property var keybindings: ({})
    property string editingAction: ""
    property string draftAccelerator: ""
    readonly property Services.ActionRegistry actionRegistry: Services.ActionRegistry {}
    readonly property var actions: actionRegistry.knownActions
    readonly property string shortPresetId: presetId.slice(0, 8)
    signal backRequested
    signal editRequested(string action, string accelerator)
    signal commandRequested(var command)
    implicitHeight: content.implicitHeight

    Text { id: title; text: "Keybindings"; color: root.colors.textPrimary; font.pixelSize: 18; font.weight: Font.DemiBold }
    Text {
        objectName: "bindingPresetSubtitle"
        anchors { top: title.bottom; topMargin: 4 }
        text: root.presetName + " · " + root.shortPresetId
        color: root.colors.textSecondary; font.pixelSize: 9
        Accessible.name: text
        Accessible.description: "Preset identifier " + root.presetId
    }
    Column {
        id: content
        anchors { top: title.bottom; topMargin: 30; left: parent.left; right: parent.right }
        spacing: 7
        Rectangle {
            width: content.width; height: 66; radius: 12
            color: root.colors.surfaceQuiet; border.width: 1
            border.color: root.presetAdapter.conflictMessage.length ? root.colors.error : root.colors.border
            Column {
                anchors { fill: parent; margins: 9 }
                spacing: 4
                Text { text: root.editingAction.length ? root.editingAction : "Select a binding below"; color: root.colors.textSecondary; font.pixelSize: 8; elide: Text.ElideRight; width: parent.width }
                TextInput { width: parent.width; text: root.draftAccelerator; color: root.colors.textPrimary; selectionColor: root.colors.accent; font.family: "monospace"; font.pixelSize: 11; enabled: root.editingAction.length > 0; onTextEdited: root.draftAccelerator = text; Keys.onReturnPressed: root.saveBinding() }
            }
        }
        Flow {
            width: content.width; spacing: 6
            Widgets.TextButton { label: "Save binding"; colors: root.colors; emphasized: true; enabled: root.editingAction.length > 0 && root.draftAccelerator.trim().length > 0; onTriggered: root.saveBinding() }
            Widgets.TextButton { label: "Unbind"; colors: root.colors; enabled: root.editingAction.length > 0; onTriggered: root.unsetBinding() }
        }
        Repeater {
            model: root.actions
            delegate: Widgets.BindingRow {
                required property string modelData
                objectName: "bindingRow-" + modelData
                width: content.width
                action: modelData
                accelerator: root.keybindings[modelData] || "Unbound"
                conflict: root.presetAdapter.conflictActions.indexOf(modelData) >= 0
                    ? root.presetAdapter.conflictMessage : ""
                colors: root.colors
                onEditRequested: (action, accelerator) => {
                    root.editingAction = action;
                    root.draftAccelerator = root.keybindings[action] || "";
                    root.editRequested(action, accelerator);
                }
            }
        }
    }

    function saveBinding() {
        const applyNow = root.presetId === root.presetAdapter.activePresetId;
        const command = root.presetAdapter.setBindingCommand(root.presetId,
            root.editingAction, root.draftAccelerator.trim(), applyNow);
        if (!command) return false;
        root.commandRequested(command); return true;
    }
    function unsetBinding() {
        const applyNow = root.presetId === root.presetAdapter.activePresetId;
        const command = root.presetAdapter.unsetBindingCommand(root.presetId,
            root.editingAction, applyNow);
        if (!command) return false;
        root.commandRequested(command); return true;
    }
}
