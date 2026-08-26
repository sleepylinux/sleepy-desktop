// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0

QtObject {
    id: root
    property int capacity: 64
    property var observed: ({})
    property var order: ([])

    function remember(requestId, generation) {
        const next = Object.assign({}, root.observed);
        let nextOrder = root.order.filter(function(id) { return id !== requestId; });
        next[requestId] = generation;
        nextOrder.push(requestId);
        while (nextOrder.length > root.capacity) {
            const expired = nextOrder.shift();
            delete next[expired];
        }
        root.observed = next;
        root.order = nextOrder;
    }

    function peek(requestId) {
        return root.observed[requestId];
    }

    function take(requestId) {
        const value = root.observed[requestId];
        if (value === undefined) return undefined;
        const next = Object.assign({}, root.observed);
        delete next[requestId];
        root.observed = next;
        root.order = root.order.filter(function(id) { return id !== requestId; });
        return value;
    }

    function clear() {
        root.observed = ({});
        root.order = ([]);
    }
}
