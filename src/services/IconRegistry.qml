import QtQuick 6.0

QtObject {
    id: root

    property string artworkRoot: "@sleepyArtworkRoot@"
    property string manifestSource: "@sleepyArtworkManifest@"

    property var assets: Object.freeze({})
    property string status: "idle"
    property string errorString: ""
    readonly property bool ready: status === "ready"
    readonly property int assetCount: Object.keys(assets).length

    property bool componentComplete: false
    property int loadGeneration: 0

    function failLoad(generation, message) {
        if (generation !== root.loadGeneration)
            return;
        root.assets = Object.freeze({});
        root.errorString = message;
        root.status = "error";
    }

    function safeRelativePath(value) {
        if (typeof value !== "string" || value.length === 0
                || value.startsWith("/") || value.includes("\\")
                || value.includes(":"))
            return false;
        const segments = value.split("/");
        return segments.every(function(segment) {
            return segment.length > 0 && segment !== "." && segment !== "..";
        });
    }

    function validatedAssets(document) {
        if (!document || document.version !== 1 || !document.assets
                || typeof document.assets !== "object"
                || Array.isArray(document.assets))
            return null;

        const names = Object.keys(document.assets);
        if (names.length === 0)
            return null;
        const validated = Object.create(null);
        for (const name of names) {
            if (typeof name !== "string" || name.trim().length === 0
                    || !root.safeRelativePath(document.assets[name]))
                return null;
            validated[name] = document.assets[name];
        }
        return Object.freeze(validated);
    }

    function requestUrl() {
        if (root.manifestSource.startsWith("/"))
            return "file://" + root.manifestSource;
        return root.manifestSource;
    }

    function loadManifest() {
        const generation = ++root.loadGeneration;
        root.assets = Object.freeze({});
        root.errorString = "";
        root.status = "loading";

        if (root.manifestSource.length === 0) {
            root.failLoad(generation, "manifestSource is empty");
            return;
        }

        const request = new XMLHttpRequest();
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE
                    || generation !== root.loadGeneration)
                return;
            if ((request.status !== 0 && request.status !== 200)
                    || request.responseText.length === 0) {
                root.failLoad(generation, "manifest could not be read");
                return;
            }
            try {
                const parsed = JSON.parse(request.responseText);
                const validated = root.validatedAssets(parsed);
                if (!validated) {
                    root.failLoad(generation, "manifest schema or asset path is invalid");
                    return;
                }
                root.assets = validated;
                root.status = "ready";
            } catch (error) {
                root.failLoad(generation, "manifest JSON is malformed");
            }
        };

        try {
            request.open("GET", root.requestUrl());
            request.send();
        } catch (error) {
            root.failLoad(generation, "manifest request failed");
        }
    }

    function sourceFor(logicalName) {
        if (!root.ready || typeof logicalName !== "string"
                || !Object.prototype.hasOwnProperty.call(root.assets, logicalName))
            return "";

        const base = root.artworkRoot.endsWith("/")
                   ? root.artworkRoot.slice(0, -1) : root.artworkRoot;
        return base + "/" + root.assets[logicalName];
    }

    onManifestSourceChanged: {
        if (root.componentComplete)
            root.loadManifest();
    }

    Component.onCompleted: {
        root.componentComplete = true;
        root.loadManifest();
    }
}
