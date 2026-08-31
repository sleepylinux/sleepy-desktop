import QtQuick 6.0
import QtTest 1.0
import "../../src/services/DesktopCommands.js" as DesktopCommands

TestCase {
    name: "DesktopCommands"

    function readCorpus() {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../fixtures/desktop-command-corpus.json"), false);
        request.send();
        verify(request.status === 0 || request.status === 200);
        return JSON.parse(request.responseText);
    }

    function invokeBuilder(entry) {
        const builder = DesktopCommands[entry.builder];
        verify(typeof builder === "function");
        return builder.apply(null, entry.args);
    }

    function test_builders_match_single_schema_corpus_data() {
        return readCorpus().map(function(entry) {
            return {"tag": entry.name, "entry": entry};
        });
    }

    function test_builders_match_single_schema_corpus(data) {
        const actual = invokeBuilder(data.entry);
        compare(JSON.stringify(actual), JSON.stringify(data.entry.command));
    }
}
