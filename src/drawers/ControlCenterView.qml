pragma ComponentBehavior: Bound

import QtQuick 6.0
import "../widgets" as Widgets

FocusScope {
    id: root
    required property var tokens
    required property var colors
    required property var effects
    required property var iconRegistry
    required property var clockService
    required property var systemAdapter
    required property var presetAdapter
    property var surfaceController: null
    property string screenKey: "default"
    property string page: "main"
    property string previousPage: "main"
    property string bindingPresetId: ""
    property string pendingSessionAction: ""
    property string confirmationReturnFocusKey: "lock"
    property string focusKey: ""
    readonly property int drawerWidth: 408
    readonly property real contentHeight: page === "main" ? Math.max(900, mainColumn.implicitHeight + 48)
                                             : page === "presets" ? presetManager.implicitHeight + 80
                                             : page === "bindings" ? bindingEditor.implicitHeight + 80
                                             : height
    readonly property var systemState: systemAdapter.snapshot
    readonly property bool hasState: systemState !== null

    signal closeRequested
    signal sessionActionConfirmed(string action, string confirmation)
    signal systemCommandRequested(var command, int generation)
    signal presetCommandRequested(var command)

    implicitWidth: drawerWidth
    implicitHeight: 720
    focus: true

    function capabilityEnabled(name) {
        return hasState && systemAdapter.capabilityState(name) === "available";
    }
    function capabilityBusy(name) {
        return typeof systemAdapter.isCapabilityBusy === "function"
            ? systemAdapter.isCapabilityBusy(name)
            : hasState && systemAdapter.capabilityState(name) === "busy";
    }
    function requestMutation(name, value) {
        if (typeof systemAdapter.mutate === "function")
            return systemAdapter.mutate(name, value);
        const command = systemAdapter.beginMutation(name, value);
        if (!command) return false;
        root.systemCommandRequested(command, systemAdapter.nextGeneration);
        return true;
    }
    function forceInitialFocus() {
        root.page = "main";
        root.focusKey = "lock";
        Qt.callLater(lockButton.forceActiveFocus);
    }
    function sessionActionEnabled(action) {
        return typeof systemAdapter.sessionActionAvailable === "function"
            && systemAdapter.sessionActionAvailable(action);
    }
    function focusControl(key) {
        root.focusKey = key;
        Qt.callLater(function() {
            if (key === "logout") logoutButton.forceActiveFocus();
            else if (key === "power") powerButton.forceActiveFocus();
            else if (key === "power-cancel") powerCancelButton.forceActiveFocus();
            else lockButton.forceActiveFocus();
        });
    }
    function openPresets() {
        root.previousPage = root.page;
        root.page = "presets";
        root.focusKey = "preset-first";
        Qt.callLater(presetManager.focusFirst);
        return true;
    }
    function presetFor(id) {
        for (let i = 0; i < presetAdapter.presets.length; ++i)
            if (presetAdapter.presets[i].id === id) return presetAdapter.presets[i];
        return null;
    }
    function outputDeviceLabel() {
        if (!root.systemState || !root.systemState.audio)
            return "None";
        const selectedId = root.systemState.audio.outputDeviceId;
        const devices = root.systemState.audio.outputDevices || [];
        for (let i = 0; i < devices.length; ++i)
            if (devices[i].id === selectedId)
                return devices[i].label;
        return selectedId ? "Unknown output" : "None";
    }
    function openBindings(id) {
        const preset = root.presetFor(id);
        if (!preset || !root.presetAdapter.canEdit(preset)) return false;
        root.bindingPresetId = id;
        bindingEditor.keybindings = preset.keybindings;
        root.page = "bindings";
        root.focusKey = "binding-first";
        return true;
    }
    function goBack() {
        if (root.page === "bindings") {
            root.page = "presets";
            root.focusKey = "preset-first";
            Qt.callLater(presetManager.focusSelected);
        } else {
            const returnKey = root.page === "power" ? "power" : "lock";
            root.page = "main";
            root.focusControl(returnKey);
        }
    }
    function requestSessionAction(action) {
        if (["logout", "reboot", "powerOff"].indexOf(action) < 0
                || !root.sessionActionEnabled(action)) return false;
        root.previousPage = root.page;
        root.confirmationReturnFocusKey = root.focusKey;
        root.pendingSessionAction = action;
        root.page = "confirm";
        root.focusKey = "cancel";
        Qt.callLater(cancelButton.forceActiveFocus);
        return true;
    }
    function openPowerMenu() {
        if (!root.sessionActionEnabled("reboot")
                && !root.sessionActionEnabled("powerOff")) return false;
        root.previousPage = root.page;
        root.page = "power";
        root.focusKey = "power-cancel";
        Qt.callLater(powerCancelButton.forceActiveFocus);
        return true;
    }
    function choosePowerAction(action) {
        if (["reboot", "powerOff"].indexOf(action) < 0)
            return false;
        return root.requestSessionAction(action);
    }
    function cancelConfirmation() {
        root.page = root.previousPage;
        root.pendingSessionAction = "";
        root.focusControl(root.page === "power" ? "power-cancel"
                          : root.confirmationReturnFocusKey);
    }
    function confirmSessionAction() {
        if (!root.pendingSessionAction.length
                || !root.sessionActionEnabled(root.pendingSessionAction)) return false;
        const action = root.pendingSessionAction;
        root.pendingSessionAction = "";
        root.page = "main";
        root.sessionActionConfirmed(action, "confirmed");
        root.focusControl(root.confirmationReturnFocusKey);
        return true;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (root.page === "main") root.closeRequested();
            else if (root.page === "confirm") root.cancelConfirmation();
            else root.goBack();
            event.accepted = true;
        } else if (root.page === "presets" && event.key === Qt.Key_Home) {
            root.focusKey = "preset-first";
            presetManager.focusFirst(); event.accepted = true;
        } else if (root.page === "presets" && event.key === Qt.Key_End) {
            root.focusKey = "preset-last";
            presetManager.focusLast(); event.accepted = true;
        } else if (root.page === "presets" && event.key === Qt.Key_Down) {
            presetManager.focusAdjacent(1); event.accepted = true;
        } else if (root.page === "presets" && event.key === Qt.Key_Up) {
            presetManager.focusAdjacent(-1); event.accepted = true;
        }
    }

    Widgets.GlassSurface {
        anchors.fill: parent
        radius: root.tokens.shellRadius
        colors: root.colors
        effects: root.effects
    }

    Flickable {
        id: flickable
        objectName: "controlCenterFlickable"
        anchors.fill: parent
        anchors.margins: root.tokens.contentPadding
        clip: true
        contentWidth: width
        contentHeight: root.contentHeight
        boundsBehavior: Flickable.StopAtBounds
        visible: root.page !== "confirm" && root.page !== "power"

        Column {
            id: mainColumn
            width: flickable.width
            spacing: 11
            visible: root.page === "main"

            Item {
                id: sessionHeader
                objectName: "sessionHeader"
                width: parent.width; height: 58
                Column {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    Text { objectName: "headerTime"; text: Qt.formatTime(root.clockService.currentTime, "hh:mm"); color: root.colors.textPrimary; font.pixelSize: 24; font.weight: Font.DemiBold }
                    Text { objectName: "headerDate"; text: Qt.formatDate(root.clockService.currentTime, "dddd, d MMMM"); color: root.colors.textSecondary; font.pixelSize: 9 }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Widgets.IconButton {
                        id: lockButton; objectName: "lockButton"; label: "Lock session"; iconName: "icons.lock"; iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors
                        enabled: root.sessionActionEnabled("lock")
                        KeyNavigation.right: logoutButton
                        KeyNavigation.tab: logoutButton
                        tabTarget: logoutButton
                        rightTarget: logoutButton
                        onActiveFocusChanged: { if (activeFocus) root.focusKey = "lock"; }
                        onTriggered: root.sessionActionConfirmed("lock", "confirmed")
                    }
                    Widgets.IconButton {
                        id: logoutButton; objectName: "logoutButton"; label: "Log out"; iconName: "icons.logout"; iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors
                        enabled: root.sessionActionEnabled("logout")
                        KeyNavigation.left: lockButton; KeyNavigation.right: powerButton
                        KeyNavigation.tab: powerButton
                        tabTarget: powerButton
                        leftTarget: lockButton
                        rightTarget: powerButton
                        onActiveFocusChanged: { if (activeFocus) root.focusKey = "logout"; }
                        onTriggered: root.requestSessionAction("logout")
                    }
                    Widgets.IconButton {
                        id: powerButton; objectName: "powerButton"; label: "Power menu"; iconName: "icons.power"; iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors; destructive: true
                        enabled: root.sessionActionEnabled("reboot") || root.sessionActionEnabled("powerOff")
                        KeyNavigation.left: logoutButton
                        leftTarget: logoutButton
                        onActiveFocusChanged: { if (activeFocus) root.focusKey = "power"; }
                        onTriggered: root.openPowerMenu()
                    }
                }
            }

            Text { text: "CONNECTIONS"; color: root.colors.textSecondary; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 1 }
            Grid {
                id: connectionsSection; objectName: "connectionsSection"; width: parent.width; columns: 2; spacing: 8
                Widgets.CompactToggle {
                    id: networkToggle; objectName: "networkToggle"; width: (connectionsSection.width - 8) / 2
                    label: "Network"; detail: root.systemState && root.systemState.network && root.systemState.network.connectedName ? root.systemState.network.connectedName : "Offline"; iconName: "icons.network"
                    checked: root.systemState && root.systemState.network ? root.systemState.network.enabled : false
                    capabilityEnabled: root.capabilityEnabled("network.enabled"); busy: root.capabilityBusy("network.enabled")
                    iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors
                    onToggled: checked => root.requestMutation("network.enabled", checked)
                }
                Widgets.CompactToggle {
                    objectName: "bluetoothToggle"; width: (connectionsSection.width - 8) / 2
                    label: "Bluetooth"; detail: root.systemState && root.systemState.bluetooth && root.systemState.bluetooth.connectedDevice ? root.systemState.bluetooth.connectedDevice : "No device"; iconName: "icons.bluetooth"
                    checked: root.systemState && root.systemState.bluetooth ? root.systemState.bluetooth.enabled : false
                    capabilityEnabled: root.capabilityEnabled("bluetooth.enabled"); busy: root.capabilityBusy("bluetooth.enabled")
                    iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors
                    onToggled: checked => root.requestMutation("bluetooth.enabled", checked)
                }
            }

            Text { text: "SOUND & DISPLAY"; color: root.colors.textSecondary; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 1 }
            Column {
                id: audioSection; objectName: "audioSection"; width: parent.width; spacing: 4
                Widgets.LevelControl { objectName: "volumeControl"; width: parent.width; label: "Volume"; iconName: "icons.volume"; value: root.systemState && root.systemState.audio ? root.systemState.audio.volume : 0; capabilityEnabled: root.capabilityEnabled("audio.volume"); busy: root.capabilityBusy("audio.volume"); iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors; onValueRequested: value => root.requestMutation("audio.volume", value) }
                Widgets.LevelControl { objectName: "microphoneControl"; width: parent.width; label: "Microphone"; iconName: "icons.microphone"; value: root.systemState && root.systemState.audio ? root.systemState.audio.microphoneLevel : 0; capabilityEnabled: root.capabilityEnabled("audio.microphoneLevel"); busy: root.capabilityBusy("audio.microphoneLevel"); iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors; onValueRequested: value => root.requestMutation("audio.microphoneLevel", value) }
                Widgets.LevelControl { objectName: "brightnessControl"; width: parent.width; label: "Brightness"; iconName: "icons.brightness"; value: root.systemState && root.systemState.display && root.systemState.display.brightness !== null ? root.systemState.display.brightness : 0; capabilityEnabled: root.capabilityEnabled("display.brightness"); busy: root.capabilityBusy("display.brightness"); iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors; onValueRequested: value => root.requestMutation("display.brightness", value) }
                Grid {
                    width: parent.width; columns: 2; spacing: 8
                    Widgets.CompactToggle { width: (parent.width - 8) / 2; label: "Mute output"; detail: "Speaker audio"; iconName: "icons.volume"; checked: root.systemState && root.systemState.audio ? root.systemState.audio.muted : false; capabilityEnabled: root.capabilityEnabled("audio.muted"); busy: root.capabilityBusy("audio.muted"); iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors; onToggled: checked => root.requestMutation("audio.muted", checked) }
                    Widgets.CompactToggle { width: (parent.width - 8) / 2; label: "Mute mic"; detail: "Microphone input"; iconName: "icons.microphone"; checked: root.systemState && root.systemState.audio ? root.systemState.audio.microphoneMuted : false; capabilityEnabled: root.capabilityEnabled("audio.microphoneMuted"); busy: root.capabilityBusy("audio.microphoneMuted"); iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors; onToggled: checked => root.requestMutation("audio.microphoneMuted", checked) }
                }
                Column {
                    width: parent.width; spacing: 5
                    Repeater {
                        model: root.systemState && root.systemState.audio ? root.systemState.audio.outputDevices : []
                        delegate: Widgets.DeviceRow {
                            required property var modelData
                            objectName: "outputDevice-" + modelData.id
                            width: parent.width
                            deviceId: modelData.id; label: modelData.label; selected: modelData.id === root.systemState.audio.outputDeviceId
                            capabilityEnabled: root.capabilityEnabled("audio.outputDevice"); colors: root.colors
                            onSelectedRequested: id => root.requestMutation("audio.outputDevice", id)
                        }
                    }
                }
                Widgets.CompactToggle { width: parent.width; label: "Night light"; detail: "Warm display colors"; iconName: "icons.night-light"; checked: root.systemState && root.systemState.display ? root.systemState.display.nightLightEnabled : false; capabilityEnabled: root.capabilityEnabled("display.nightLightEnabled"); busy: root.capabilityBusy("display.nightLightEnabled"); iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors; onToggled: checked => root.requestMutation("display.nightLightEnabled", checked) }
            }

            Text { text: "POWER & STATUS"; color: root.colors.textSecondary; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 1 }
            Flow {
                id: powerSection; objectName: "powerSection"; width: parent.width; spacing: 6
                Widgets.InfoChip { label: "Battery"; value: root.systemState && root.systemState.power && root.systemState.power.batteryLevel !== null ? Math.round(root.systemState.power.batteryLevel * 100) + "%" : "No battery"; colors: root.colors }
                Widgets.InfoChip { label: "Profile"; value: root.systemState && root.systemState.power && root.systemState.power.currentProfile ? root.systemState.power.currentProfile : "Unsupported"; colors: root.colors }
                Widgets.InfoChip { objectName: "outputDeviceSummary"; label: "Output"; value: root.outputDeviceLabel(); colors: root.colors }
            }
            Flow {
                width: parent.width; spacing: 6
                Repeater {
                    model: root.systemState && root.systemState.power ? root.systemState.power.availableProfiles : []
                    delegate: Widgets.TextButton {
                        required property string modelData
                        objectName: "powerProfile-" + modelData
                        label: modelData
                        colors: root.colors
                        emphasized: root.systemState.power.currentProfile === modelData
                        enabled: root.capabilityEnabled("power.profile") && !root.capabilityBusy("power.profile")
                        onTriggered: root.requestMutation("power.profile", modelData)
                    }
                }
            }

            Text { text: "NOW PLAYING"; color: root.colors.textSecondary; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 1 }
            Widgets.MediaCard {
                id: mediaSection; objectName: "mediaSection"; width: parent.width
                media: root.systemState ? root.systemState.media : null
                capabilityEnabled: root.capabilityEnabled("media.transport"); busy: root.capabilityBusy("media.transport")
                iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors
                onTransportRequested: transport => root.requestMutation("media.transport", transport)
            }

            Rectangle {
                id: presetSection; objectName: "presetSection"; width: parent.width; height: 64; radius: root.tokens.innerRadius; color: root.colors.surfaceRaised; border.width: 1; border.color: root.colors.border
                Widgets.SleepyIcon {
                    anchors { left: parent.left; leftMargin: 13; verticalCenter: parent.verticalCenter }
                    iconRegistry: root.iconRegistry; name: "icons.preset"; iconColor: root.colors.accent; iconSize: 20; accessibleName: ""
                }
                Column {
                    anchors { left: parent.left; leftMargin: 44; right: managePreset.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Text { text: "Named presets"; color: root.colors.textPrimary; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Text { text: root.presetAdapter.presets.length + " available · bindings editable"; color: root.colors.textSecondary; font.pixelSize: 9 }
                }
                Widgets.IconButton {
                    id: managePreset
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    compact: true; label: "Manage presets and bindings"; iconName: "icons.keybinding"; iconRegistry: root.iconRegistry; tokens: root.tokens; colors: root.colors
                    onTriggered: root.openPresets()
                }
            }

            Rectangle {
                id: adapterDiagnostic; objectName: "adapterDiagnostic"; width: parent.width; height: 46; radius: 13
                color: root.systemAdapter.diagnostic.length || root.presetAdapter.diagnostic.length ? root.colors.surfaceQuiet : root.colors.accentSoft
                Text {
                    anchors { fill: parent; margins: 10 }
                    text: root.systemAdapter.diagnostic.length ? root.systemAdapter.diagnostic : root.presetAdapter.diagnostic.length ? root.presetAdapter.diagnostic : "All available adapters confirmed"
                    color: root.systemAdapter.diagnostic.length || root.presetAdapter.diagnostic.length ? root.colors.warning : root.colors.success
                    font.pixelSize: 9; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                }
            }
        }

        PresetManagerView {
            id: presetManager
            objectName: "presetManager"
            width: flickable.width
            visible: root.page === "presets"
            presetAdapter: root.presetAdapter
            activePresetId: root.presetAdapter.activePresetId
            colors: root.colors
            onBindingEditorRequested: id => root.openBindings(id)
            onCommandRequested: command => root.presetCommandRequested(command)
            onExportRequested: command => root.presetCommandRequested(command)
        }
        BindingEditorView {
            id: bindingEditor
            objectName: "bindingEditor"
            width: flickable.width
            visible: root.page === "bindings"
            presetAdapter: root.presetAdapter
            presetId: root.bindingPresetId
            presetName: {
                const preset = root.presetFor(root.bindingPresetId);
                return preset ? preset.name : "Preset";
            }
            colors: root.colors
            onCommandRequested: command => root.presetCommandRequested(command)
        }
    }

    Item {
        objectName: "scrollIndicator"
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom; margins: 8 }
        width: 3
        readonly property bool overflow: root.page !== "confirm" && root.page !== "power"
                                         && flickable.contentHeight > flickable.height
        visible: overflow
        Rectangle {
            width: parent.width
            height: Math.max(38, parent.height * flickable.visibleArea.heightRatio)
            y: parent.height * flickable.visibleArea.yPosition
            radius: width / 2
            color: root.colors.accent
            opacity: flickable.moving ? 0.78 : 0.38
            Behavior on opacity { NumberAnimation { duration: root.tokens.motionDuration } }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.tokens.contentPadding
        visible: root.page === "confirm"
        radius: root.tokens.innerRadius
        color: root.colors.surfaceRaised
        border.width: 1
        border.color: root.colors.border
        Column {
            anchors.centerIn: parent; width: Math.min(parent.width - 48, 300); spacing: 14
            Widgets.SleepyIcon { anchors.horizontalCenter: parent.horizontalCenter; iconRegistry: root.iconRegistry; name: "icons.power"; iconColor: root.colors.error; iconSize: 34; accessibleName: "Power confirmation" }
            Text { width: parent.width; text: root.pendingSessionAction === "logout" ? "Log out of Sleepy?" : root.pendingSessionAction === "reboot" ? "Restart the system?" : "Power off the system?"; color: root.colors.textPrimary; font.pixelSize: 18; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
            Text { width: parent.width; text: "Unsaved work may be lost. This action runs only after explicit confirmation."; color: root.colors.textSecondary; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
                Widgets.TextButton {
                    id: cancelButton; label: "Cancel"; colors: root.colors
                    onActiveFocusChanged: { if (activeFocus) root.focusKey = "cancel"; }
                    onTriggered: root.cancelConfirmation()
                }
                Widgets.TextButton {
                    id: confirmButton
                    label: root.pendingSessionAction === "reboot" ? "Restart" : root.pendingSessionAction === "logout" ? "Log out" : "Power off"
                    colors: root.colors; destructive: true
                    onActiveFocusChanged: { if (activeFocus) root.focusKey = "confirm"; }
                    onTriggered: root.confirmSessionAction()
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.tokens.contentPadding
        visible: root.page === "power"
        radius: root.tokens.innerRadius
        color: root.colors.surfaceRaised
        border.width: 1
        border.color: root.colors.border
        Column {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 300)
            spacing: 14
            Widgets.SleepyIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                iconRegistry: root.iconRegistry; name: "icons.power"; iconColor: root.colors.accent; iconSize: 34
                accessibleName: "Power menu"
            }
            Text { width: parent.width; text: "Power menu"; color: root.colors.textPrimary; font.pixelSize: 18; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
            Text { width: parent.width; text: "Choose an action. Nothing happens until the next confirmation step."; color: root.colors.textSecondary; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Widgets.TextButton {
                    id: powerCancelButton; label: "Cancel"; colors: root.colors
                    onTriggered: root.goBack()
                }
                Widgets.TextButton {
                    label: "Restart"; colors: root.colors
                    enabled: root.sessionActionEnabled("reboot")
                    onTriggered: root.choosePowerAction("reboot")
                }
                Widgets.TextButton {
                    label: "Power off"; colors: root.colors; destructive: true
                    enabled: root.sessionActionEnabled("powerOff")
                    onTriggered: root.choosePowerAction("powerOff")
                }
            }
        }
    }

    Connections {
        target: root.surfaceController
        enabled: root.surfaceController !== null
        function onSessionConfirmationRequested(action, screenKey) {
            if (screenKey === root.screenKey)
                root.requestSessionAction(action);
        }
        function onPowerMenuRequested(screenKey) {
            if (screenKey === root.screenKey)
                root.openPowerMenu();
        }
    }
}
