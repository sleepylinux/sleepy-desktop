// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0

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
        containsAll(recorder, ["extraArgs.some(arg => arg.includes(\"r\"))", "extraArgs.some(arg => arg.includes(\"s\"))", "utilityStartRecording(outputId, withAudio)", "function deleteRecording(path: string)", "utilityDeleteRecording"]);
        containsAll(modal, ["Recorder.deleteRecording(root.props.recordingConfirmDelete)"]);
        verify(modal.indexOf("CUtils.deleteFile") < 0);
    }

    function test_session_surface_keeps_original_animation_and_only_closed_native_actions() {
        const content = source("../../src/modules/session/Content.qml");
        const wrapper = source("../../src/modules/session/Wrapper.qml");
        containsAll(content, ["Config.session.icons.logout", "Config.session.icons.shutdown", "Config.session.icons.hibernate", "Config.session.icons.reboot", "SessionManager.exec(command)", "Keys.onEscapePressed"]);
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
