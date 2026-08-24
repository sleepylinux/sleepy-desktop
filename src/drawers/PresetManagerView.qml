pragma ComponentBehavior: Bound

import QtQuick 6.0
import "../widgets" as Widgets

FocusScope {
    id: root
    required property var presetAdapter
    required property var colors
    property string activePresetId: ""
    property string selectedPresetId: activePresetId
    property string draftName: "My Sleepy preset"
    property string transferPath: ""
    property string importMode: "copy"
    property bool pendingEditCopy: false
    readonly property int rowCount: repeater.count
    readonly property var selectedPresetValue: selectedPreset()
    signal bindingEditorRequested(string presetId)
    signal backRequested
    signal commandRequested(var command)
    signal exportRequested(var command)

    implicitHeight: content.implicitHeight + 126

    function selectedPreset() {
        for (let i = 0; i < presetAdapter.presets.length; ++i)
            if (presetAdapter.presets[i].id === root.selectedPresetId)
                return presetAdapter.presets[i];
        return null;
    }
    function createCopy() {
        const source = root.selectedPresetId.length ? root.selectedPresetId : root.activePresetId;
        const command = root.presetAdapter.duplicateCommand(source, root.draftName.trim());
        if (!command) return false;
        root.commandRequested(command); return true;
    }
    function renameSelected() {
        const selected = root.selectedPreset();
        if (!selected || !root.presetAdapter.canEdit(selected)) return false;
        const command = root.presetAdapter.renameCommand(selected.id, root.draftName.trim());
        if (!command) return false;
        root.commandRequested(command); return true;
    }
    function activateSelected() {
        if (!root.selectedPresetValue
                || root.selectedPresetId === root.activePresetId) return false;
        root.commandRequested(root.presetAdapter.activateCommand(root.selectedPresetId));
        return true;
    }
    function editPreset(id) {
        const preset = root.presetAdapter.presets.find(function(item) {
            return item.id === id;
        });
        if (!preset) return false;
        if (root.presetAdapter.canEdit(preset)) {
            root.bindingEditorRequested(id);
            return true;
        }
        const command = root.presetAdapter.duplicateCommand(id, preset.name + " copy");
        if (!command) return false;
        root.pendingEditCopy = true;
        root.commandRequested(command);
        return true;
    }
    function deleteSelected() {
        const selected = root.selectedPreset();
        if (!selected || !root.presetAdapter.canEdit(selected)
                || selected.id === root.activePresetId) return false;
        root.commandRequested(root.presetAdapter.deleteCommand(selected.id)); return true;
    }
    function importPath() {
        const command = root.presetAdapter.importCommand(
            root.transferPath.trim(), root.importMode, false);
        if (!command) return false;
        root.commandRequested(command); return true;
    }
    function focusFirst() {
        if (!repeater.count) return false;
        repeater.itemAt(0).forceActiveFocus();
        return true;
    }
    function focusLast() {
        if (!repeater.count) return false;
        repeater.itemAt(repeater.count - 1).forceActiveFocus();
        return true;
    }
    function focusAdjacent(delta) {
        for (let i = 0; i < repeater.count; ++i) {
            if (!repeater.itemAt(i).activeFocus) continue;
            const target = Math.max(0, Math.min(repeater.count - 1, i + delta));
            repeater.itemAt(target).forceActiveFocus();
            return true;
        }
        return delta > 0 ? root.focusFirst() : root.focusLast();
    }
    function focusSelected() {
        for (let i = 0; i < repeater.count; ++i) {
            if (repeater.itemAt(i).objectName
                    !== "presetRow-" + root.selectedPresetId) continue;
            repeater.itemAt(i).forceActiveFocus();
            return true;
        }
        return root.focusFirst();
    }

    Text {
        id: title
        anchors { top: parent.top; left: parent.left }
        text: "Named presets"
        color: root.colors.textPrimary
        font.pixelSize: 18
        font.weight: Font.DemiBold
    }
    Text {
        anchors { top: title.bottom; left: parent.left; right: parent.right; topMargin: 4 }
        text: "Built-ins stay immutable. Editing creates an update-safe user copy."
        color: root.colors.textSecondary
        wrapMode: Text.Wrap
        font.pixelSize: 9
    }
    Column {
        id: content
        anchors { top: title.bottom; topMargin: 42; left: parent.left; right: parent.right }
        spacing: 8
        Rectangle {
            width: content.width; height: 42; radius: 12
            color: root.colors.surfaceQuiet; border.width: 1; border.color: root.colors.border
            TextInput {
                anchors { fill: parent; margins: 11 }
                text: root.draftName
                color: root.colors.textPrimary
                selectionColor: root.colors.accent
                font.pixelSize: 10
                onTextEdited: root.draftName = text
                Accessible.name: "Preset name"
            }
        }
        Flow {
            width: content.width; spacing: 6
            Widgets.TextButton { label: "Create copy"; colors: root.colors; emphasized: true; enabled: root.selectedPresetId.length > 0; onTriggered: root.createCopy() }
            Widgets.TextButton { label: "Activate"; colors: root.colors; enabled: root.selectedPresetValue && root.selectedPresetId !== root.activePresetId; onTriggered: root.activateSelected() }
            Widgets.TextButton { label: "Rename"; colors: root.colors; enabled: root.selectedPresetValue && root.presetAdapter.canEdit(root.selectedPresetValue); onTriggered: root.renameSelected() }
            Widgets.TextButton { label: "Delete"; colors: root.colors; destructive: true; enabled: root.selectedPresetValue && root.presetAdapter.canEdit(root.selectedPresetValue) && root.selectedPresetValue.id !== root.activePresetId; onTriggered: root.deleteSelected() }
            Widgets.TextButton { label: "Export"; colors: root.colors; enabled: root.selectedPresetId.length > 0; onTriggered: root.exportRequested(root.presetAdapter.exportCommand(root.selectedPresetId)) }
        }
        Rectangle {
            width: content.width; height: 38; radius: 11
            color: root.colors.surfaceQuiet; border.width: 1; border.color: root.colors.border
            TextInput {
                anchors { fill: parent; margins: 10 }
                text: root.transferPath; color: root.colors.textPrimary; font.pixelSize: 9
                onTextEdited: root.transferPath = text
                Accessible.name: "Preset import JSON path"
            }
        }
        Flow {
            width: content.width; spacing: 6
            Widgets.TextButton { label: "Reject existing"; colors: root.colors; emphasized: root.importMode === "reject"; onTriggered: root.importMode = "reject" }
            Widgets.TextButton { label: "Copy with new ID"; colors: root.colors; emphasized: root.importMode === "copy"; onTriggered: root.importMode = "copy" }
            Widgets.TextButton { label: "Replace user preset"; colors: root.colors; emphasized: root.importMode === "replace"; onTriggered: root.importMode = "replace" }
        }
        Widgets.TextButton { label: "Import copy"; colors: root.colors; enabled: root.transferPath.trim().length > 0; onTriggered: root.importPath() }
        Rectangle {
            width: content.width
            visible: root.presetAdapter.lastExportJson.length > 0
            height: visible ? 90 : 0
            radius: 11; color: root.colors.surfaceQuiet
            border.width: visible ? 1 : 0; border.color: root.colors.success
            TextEdit {
                objectName: "exportPayload"
                anchors { fill: parent; margins: 9 }
                text: root.presetAdapter.lastExportJson
                color: root.colors.textPrimary
                font.family: "monospace"; font.pixelSize: 8
                readOnly: true; selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                Accessible.name: "Exported preset JSON; select to copy"
            }
        }
        Repeater {
            id: repeater
            model: root.presetAdapter.presets
            delegate: Widgets.PresetRow {
                required property var modelData
                objectName: "presetRow-" + modelData.id
                width: content.width
                presetId: modelData.id
                label: root.presetAdapter.displayName(modelData)
                active: modelData.id === root.activePresetId
                editable: root.presetAdapter.canEdit(modelData)
                colors: root.colors
                onActivated: id => root.selectedPresetId = id
                onEditRequested: id => root.editPreset(id)
            }
        }
    }

    Connections {
        target: root.presetAdapter
        function onCopyCreated(presetId) {
            if (!root.pendingEditCopy) return;
            root.pendingEditCopy = false;
            root.bindingEditorRequested(presetId);
        }
    }
}
