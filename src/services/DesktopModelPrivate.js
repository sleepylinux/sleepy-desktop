.pragma library

let projection = null;

function initialize(factory) {
    if (!projection && factory)
        projection = factory.createObject(null);
    return projection !== null;
}

function synchronize(connectionState, diagnostic, snapshot, generation, snapshotReceived) {
    if (!projection)
        return false;
    if (connectionState === "ready" && snapshotReceived)
        return projection.applyFullSnapshot(snapshot, generation);
    projection.setConnectionState(connectionState, diagnostic);
    return false;
}

function value(name, fallback) {
    if (!projection || projection[name] === undefined)
        return fallback;
    return projection[name];
}

function capability(section, key) {
    return projection ? projection.capability(section, key) : Object.freeze({
        "status": "unavailable",
        "diagnostic": Object.freeze({"message": "Capability has not reported"})
    });
}

function capabilityData(section, key, fallback) {
    return projection ? projection.capabilityData(section, key, fallback) : fallback;
}

function focusedWorkspaceForMonitor(monitorId) {
    return projection ? projection.focusedWorkspaceForMonitor(monitorId) : null;
}

function focusedWindowForMonitor(monitorId) {
    return projection ? projection.focusedWindowForMonitor(monitorId) : null;
}

function monitorHasFullscreen(monitorId) {
    return projection ? projection.monitorHasFullscreen(monitorId) : false;
}

function occupiedWorkspaceIds(monitorId) {
    return projection ? projection.occupiedWorkspaceIds(monitorId) : [];
}

function specialWorkspaceIds(monitorId) {
    return projection ? projection.specialWorkspaceIds(monitorId) : [];
}

function capabilityAvailable(section, key) {
    return projection ? projection.capabilityAvailable(section, key) : false;
}

function capabilityDiagnostic(section, key) {
    return projection ? projection.capabilityDiagnostic(section, key) : "Capability has not reported";
}

function producerAvailable(section) {
    return projection ? projection.producerAvailable(section) : false;
}

function producerDiagnostic(section) {
    return projection ? projection.producerDiagnostic(section) : "Producer has not reported";
}
