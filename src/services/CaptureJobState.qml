// SPDX-License-Identifier: GPL-3.0-only
import QtQuick 6.0

QtObject {
    id: root
    property string state: "idle"
    readonly property bool terminal: ["completed", "cancelled", "failed"].indexOf(state) >= 0
    signal reported(string state, string code, string message)
    signal exitRequested(int code)
    function begin() {
        if (state !== "idle") return false;
        state = "awaitingConsent"; reported(state, "", ""); return true;
    }
    function consent() {
        if (state !== "awaitingConsent") return false;
        state = "capturing"; reported(state, "", ""); return true;
    }
    function completed(ok, width, height) {
        if (state !== "capturing") return false;
        if (!ok || !Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1 || width > 32768 || height > 32768)
            return fail("captureFailed", "The screenshot could not be saved");
        state = "completed"; reported(state, "", ""); exitRequested(0); return true;
    }
    function cancel() {
        if (terminal) return false;
        state = "cancelled"; reported(state, "", ""); exitRequested(0); return true;
    }
    function fail(code, message) {
        if (terminal) return false;
        state = "failed"; reported(state, code, message); exitRequested(1); return true;
    }
}
