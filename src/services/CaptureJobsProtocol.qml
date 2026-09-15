// SPDX-License-Identifier: GPL-3.0-only
// Opt-in capture v1 client state; independent of the closed desktop v3 stream.
import QtQuick 6.0

QtObject {
    id: root
    property var job: null
    property var capabilities: null
    property string errorString: ""
    property string activeJobId: ""
    property string activeOutputId: ""
    property var pendingCommand: null
    property bool cancelWanted: false
    readonly property bool active: activeJobId.length > 0
    readonly property bool busy: pendingCommand !== null
    signal requestReady(var request)

    function exact(value, required, optional) {
        return value && typeof value === "object" && !Array.isArray(value)
            && required.every(k => Object.prototype.hasOwnProperty.call(value, k))
            && Object.keys(value).every(k => required.concat(optional || []).indexOf(k) >= 0);
    }
    function bytes(text) { try { return unescape(encodeURIComponent(text)).length; } catch (_) { return Infinity; } }
    function uuid(value) { return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value); }
    function output(value) { return typeof value === "string" && /^output:[A-Za-z0-9_.-]{1,128}$/.test(value); }
    function diagnostic(value) {
        return exact(value, ["code", "message"])
            && ["unavailable", "busy", "notFound", "invalidRequest", "outputUnavailable", "consentTimedOut", "captureFailed", "cancelled"].indexOf(value.code) >= 0
            && typeof value.message === "string" && bytes(value.message) >= 1 && bytes(value.message) <= 256
            && !/[\x00-\x1f\x7f-\x9f]/.test(value.message);
    }
    function validJob(value) {
        if (!exact(value, ["jobId", "outputId", "state"], ["result", "diagnostic"])
                || !uuid(value.jobId) || !output(value.outputId)
                || ["awaitingConsent", "capturing", "completed", "cancelled", "failed"].indexOf(value.state) < 0)
            return false;
        if (("result" in value) !== (value.state === "completed") || ("diagnostic" in value) !== (value.state === "failed")) return false;
        if (value.state === "failed" && !diagnostic(value.diagnostic)) return false;
        if (value.state !== "completed") return true;
        const r = value.result;
        if (!exact(r, ["path", "mimeType", "width", "height"]) || r.mimeType !== "image/png"
                || !Number.isInteger(r.width) || !Number.isInteger(r.height)
                || r.width < 1 || r.width > 32768 || r.height < 1 || r.height > 32768 || typeof r.path !== "string") return false;
        const match = /^\/run\/user\/(0|[1-9][0-9]{0,9})\/sleepy\/captures\/screenshot-([0-9a-f-]+)\.png$/.exec(r.path);
        return !!match && Number(match[1]) <= 4294967295 && match[2] === value.jobId;
    }
    function issue(command) {
        if (busy) return false;
        pendingCommand = command;
        requestReady({schemaVersion: 1, command: command});
        return true;
    }
    function begin(outputId, jobId) {
        if (active || busy || !output(outputId) || !uuid(jobId)) return false;
        errorString = "";
        activeJobId = jobId; activeOutputId = outputId; cancelWanted = false;
        return issue({type: "begin", jobId: jobId, outputId: outputId});
    }
    function status() { return active && issue({type: "status", jobId: activeJobId}); }
    function refreshCapabilities() { return !active && issue({type: "capabilities"}); }
    function cancel() {
        if (!active) return false;
        cancelWanted = true;
        advanceCancel();
        return true;
    }
    function advanceCancel() {
        if (cancelWanted && active && !busy) {
            cancelWanted = false;
            issue({type: "cancel", jobId: activeJobId});
        }
    }
    function transportFailed(message) {
        pendingCommand = null;
        errorString = message;
        // An ambiguous begin failure is followed only by status, never replay.
        Qt.callLater(root.advanceCancel);
        return false;
    }
    function accept(line) {
        if (!busy) return false;
        const command = pendingCommand;
        let reply;
        try { if (bytes(line) > 4096) throw new Error(); reply = JSON.parse(line); }
        catch (_) { return transportFailed("Invalid capture response"); }
        if (!exact(reply, ["schemaVersion", "payload"]) || reply.schemaVersion !== 1)
            return transportFailed("Invalid capture response");
        const payload = reply.payload;
        if (exact(payload, ["type", "diagnostic"]) && payload.type === "error" && diagnostic(payload.diagnostic)) {
            if (command.type === "begin" || payload.diagnostic.code === "notFound") {
                activeJobId = ""; activeOutputId = ""; cancelWanted = false;
            }
            return transportFailed(payload.diagnostic.message);
        }
        if (command.type === "capabilities") {
            if (!exact(payload, ["type", "screenshot", "colorPicker"]) || payload.type !== "capabilities"
                    || typeof payload.screenshot !== "boolean" || payload.colorPicker !== false)
                return transportFailed("Invalid capture capabilities");
            capabilities = Object.freeze(payload);
        } else {
            if (!exact(payload, ["type", "job"]) || payload.type !== "job" || !validJob(payload.job)
                    || payload.job.jobId !== activeJobId || payload.job.outputId !== activeOutputId)
                return transportFailed("Invalid capture job response");
            // Once capture started, a stale awaiting-consent reply cannot regress it.
            if (job && job.jobId === activeJobId && job.state === "capturing" && payload.job.state === "awaitingConsent")
                return transportFailed("Capture state regressed");
            job = Object.freeze(payload.job);
            if (["completed", "cancelled", "failed"].indexOf(job.state) >= 0) {
                activeJobId = ""; activeOutputId = ""; cancelWanted = false;
            }
        }
        pendingCommand = null; errorString = "";
        Qt.callLater(root.advanceCancel);
        return true;
    }
}
