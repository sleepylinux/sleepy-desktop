// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0
import "../../src/services/DesktopCommands.js" as DesktopCommands

TestCase {
    name: "FullUtilitiesSession"

    function source(relativePath) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl(relativePath), false);
        request.send();
        return request.responseText;
    }

    function containsAll(text, fragments) {
        for (const fragment of fragments)
            verify(text.indexOf(fragment) >= 0, "missing production contract: " + fragment);
    }

    function test_utility_cards_keep_recording_modes_controls_history_and_toggles() {
        const content = source("../../src/modules/utilities/Content.qml");
        const record = source("../../src/modules/utilities/cards/Record.qml");
        const list = source("../../src/modules/utilities/cards/RecordingList.qml");
        const toggles = source("../../src/modules/utilities/cards/Toggles.qml");
        containsAll(content, ["IdleInhibit", "Record", "Toggles", "RecordingDeleteModal"]);
        containsAll(record, ["Recorder.start()", "Recorder.start([\"-r\"])", "Recorder.start([\"-s\"])", "Recorder.start([\"-sr\"])", "Recorder.togglePause()", "Recorder.stop()"]);
        containsAll(list, ["FileSystemModel", "recording_*.mp4", "GlobalConfig.general.apps.playback", "GlobalConfig.general.apps.explorer"]);
        containsAll(toggles, ["Nmcli.toggleWifi()", "Bluetooth.defaultAdapter", "GameMode.enabled", "Notifs.dnd", "VPN.toggle()"]);
    }

    function test_recorder_maps_region_and_audio_independently_and_deletes_through_daemon() {
        const recorder = source("../../src/services/Recorder.qml");
        const modal = source("../../src/modules/utilities/RecordingDeleteModal.qml");
        const region = DesktopCommands.parseRecordingRegion("640x480+-100+20\n");
        compare(JSON.stringify(region), JSON.stringify({"x": -100, "y": 20, "width": 640, "height": 480}));
        for (const audio of [false, true]) {
            const full = DesktopCommands.utilityStartRecording("DP-1", "output", audio);
            const area = DesktopCommands.utilityStartRecording("DP-1", "region", audio, region);
            compare(full.data.target, "output");
            compare(full.data.region, undefined);
            compare(area.data.region.width, 640);
            compare(area.data.region.x, -100);
            compare(area.data.audio, audio);
            compare(full.data.audio, audio);
            verify(DesktopCommands.validUtilityCommand(area));
        }
        compare(DesktopCommands.utilityStartRecording("DP-1", "region", false), null);
        for (const invalid of ["", "0x480+0+0", "640x480+999999+0", "640x480+0+0;exec", "32769x1+0+0"])
            compare(DesktopCommands.parseRecordingRegion(invalid), null);
        verify(recorder.indexOf('"active"') < 0);
        verify(recorder.indexOf('"selection"') < 0);
        containsAll(modal, ["Recorder.deleteRecording(root.props.recordingConfirmDelete)"]);
        verify(modal.indexOf("CUtils.deleteFile") < 0);
    }

    function test_session_surface_keeps_original_animation_and_only_closed_native_actions() {
        const content = source("../../src/modules/session/Content.qml");
        const wrapper = source("../../src/modules/session/Wrapper.qml");
        containsAll(content, ["Config.session.icons.logout", "Config.session.icons.shutdown", "Config.session.icons.hibernate", "Config.session.icons.reboot", "SessionActions.perform(action)", "pendingAction", "Keys.onEscapePressed"]);
        containsAll(wrapper, ["Behavior on offsetScale", "Anim {}", "screenState.session"]);
        verify(content.indexOf("Quickshell.execDetached(command)") < 0);
    }

    function test_secure_locker_view_has_redacted_visual_interface_only() {
        const root = source("../../locker/qml/LockRoot.qml");
        const view = source("../../locker/qml/SleepyLockView.qml");
        containsAll(root, ["SleepyLockView", "inputLength: prompt.inputLength", "authState: prompt.authState", "onAuthenticateRequested: prompt.authenticate()"]);
        containsAll(view, ["required property int inputLength", "required property int authState", "property string clockText", "property var media", "property var weather", "property var notificationSummary", "property var resources", "property size outputSize", "unlockAnimation", "initialAnimation"]);
        verify(view.indexOf("property string pass" + "word") < 0);
        verify(view.indexOf("property string text") < 0);
        verify(view.indexOf("function unlock") < 0);
        verify(view.indexOf("IpcHandler") < 0);
    }
}
