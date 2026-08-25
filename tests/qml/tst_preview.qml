import QtQuick 6.0
import QtTest 1.0
import "../../src/preview" as Preview

TestCase {
    id: testCase

    name: "SettingsPreview"

    readonly property url tintFixture: Qt.resolvedUrl("../fixtures/current-color.svg")
    readonly property url fixtureRoot: Qt.resolvedUrl("../fixtures")
    readonly property url validManifest:
        Qt.resolvedUrl("../fixtures/manifest-valid.json")

    Component {
        id: previewFactory

        Preview.PreviewState {}
    }

    function test_changes_are_local_to_one_preview_instance() {
        const edited = createTemporaryObject(previewFactory, testCase);
        edited.setAppearanceMode("light");
        edited.setEffectsProfile("none");
        edited.setReducedMotion(true);

        compare(edited.appearanceMode, "light");
        compare(edited.effectsProfile, "none");
        compare(edited.reducedMotion, true);

        const reopened = createTemporaryObject(previewFactory, testCase);
        compare(reopened.appearanceMode, "dark");
        compare(reopened.effectsProfile, "full");
        compare(reopened.reducedMotion, false);
    }

    function test_invalid_preview_choices_are_rejected_without_state_change() {
        const preview = createTemporaryObject(previewFactory, testCase);

        compare(preview.setAppearanceMode("sepia"), false);
        compare(preview.setEffectsProfile("maximum"), false);
        compare(preview.appearanceMode, "dark");
        compare(preview.effectsProfile, "full");
    }

    function test_default_preview_registers_then_opens_control_center() {
        const component = Qt.createComponent(
            Qt.resolvedUrl("../../src/preview/main.qml"));
        tryCompare(component, "status", Component.Ready);
        if (component.status !== Component.Ready)
            fail(component.errorString());

        const preview = createTemporaryObject(component, testCase, {
            "visible": false,
            "primaryMarkSource": tintFixture,
            "artworkRoot": fixtureRoot,
            "manifestSource": validManifest
        });
        verify(preview !== null);
        verify(preview.surfaceController !== undefined);
        verify(preview.surfaceRegistry !== undefined);
        compare(preview.surfaceRegistry.descriptorCount, 1);
        compare(preview.surfaceController.openSurfaceId, "controlCenter");
        compare(preview.surfaceController.openScreenKey, "default");
        verify(preview.iconRegistry !== undefined);
        tryCompare(preview.iconRegistry, "status", "ready");
        compare(preview.iconRegistry.sourceFor("icons.network").toString(),
                tintFixture.toString());
    }
}
