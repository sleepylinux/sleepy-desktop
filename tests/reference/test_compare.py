import json
import importlib.util
import pathlib
import tempfile
import unittest

import numpy as np
from PIL import Image

SPEC = importlib.util.spec_from_file_location("reference_compare", pathlib.Path(__file__).with_name("compare.py"))
compare = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(compare)


class ReferenceComparatorTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def image(self, name, pixels):
        path = self.root / name
        Image.fromarray(np.array(pixels, dtype=np.uint8), "RGBA").save(path)
        return path

    def mask(self, value):
        path = self.root / "mask.json"
        path.write_text(json.dumps(value))
        return path

    def test_exact_match_reports_zero_delta(self):
        pixels = np.full((4, 5, 4), [20, 30, 40, 255], dtype=np.uint8)
        report = compare.compare_paths(self.image("a.png", pixels), self.image("b.png", pixels), self.mask({"regions": []}))
        self.assertTrue(report["passed"])
        self.assertEqual(report["differingPixelsOutsideMasks"], 0)
        self.assertEqual(report["maximumChannelDelta"], 0)

    def test_branding_mask_allows_only_covered_difference(self):
        reference = np.zeros((5, 5, 4), dtype=np.uint8)
        candidate = reference.copy()
        candidate[1, 1] = [255, 255, 255, 255]
        report = compare.compare_paths(self.image("a.png", reference), self.image("b.png", candidate), self.mask({"regions": [{"name": "branding", "bounds": [1, 1, 1, 1]}]}))
        self.assertTrue(report["passed"])
        self.assertEqual(report["maskedDifferingPixels"], 1)

    def test_one_pixel_outside_mask_fails(self):
        reference = np.zeros((5, 5, 4), dtype=np.uint8)
        candidate = reference.copy()
        candidate[4, 4] = [1, 0, 0, 0]
        report = compare.compare_paths(self.image("a.png", reference), self.image("b.png", candidate), self.mask({"regions": [{"name": "branding", "bounds": [0, 0, 1, 1]}]}))
        self.assertFalse(report["passed"])
        self.assertEqual(report["differingPixelsOutsideMasks"], 1)

    def test_missing_required_surface_fails(self):
        reference = np.zeros((6, 6, 4), dtype=np.uint8)
        candidate = reference.copy()
        reference[2:4, 2:4] = [50, 60, 70, 255]
        report = compare.compare_paths(self.image("a.png", reference), self.image("b.png", candidate), self.mask({"regions": [], "surfaces": [{"name": "panel", "bounds": [2, 2, 2, 2], "minVisiblePixels": 4}]}))
        self.assertFalse(report["passed"])
        self.assertEqual(report["surfaces"][0]["candidateVisiblePixels"], 0)

    def test_wrong_opacity_fails(self):
        reference = np.zeros((2, 2, 4), dtype=np.uint8)
        candidate = reference.copy()
        reference[0, 0] = [10, 20, 30, 180]
        candidate[0, 0] = [10, 20, 30, 181]
        report = compare.compare_paths(self.image("a.png", reference), self.image("b.png", candidate), self.mask({"regions": []}))
        self.assertFalse(report["passed"])
        self.assertEqual(report["maximumChannelDelta"], 1)

    def test_animation_frame_count_and_timestamp_drift_fail(self):
        reference = self.root / "reference"
        candidate = self.root / "candidate"
        reference.mkdir()
        candidate.mkdir()
        pixel = np.full((2, 2, 4), 255, dtype=np.uint8)
        for directory, count in ((reference, 2), (candidate, 1)):
            frames = []
            for index in range(count):
                name = f"{index:03}.png"
                Image.fromarray(pixel, "RGBA").save(directory / name)
                frames.append({"file": name, "timestampMs": index * 16})
            (directory / "timeline.json").write_text(json.dumps({"frames": frames}))
        report = compare.compare_paths(reference, candidate, self.mask({"regions": []}))
        self.assertFalse(report["passed"])
        self.assertEqual(report["referenceFrameCount"], 2)
        self.assertEqual(report["candidateFrameCount"], 1)

        Image.fromarray(pixel, "RGBA").save(candidate / "001.png")
        (candidate / "timeline.json").write_text(json.dumps({"frames": [{"file": "000.png", "timestampMs": 0}, {"file": "001.png", "timestampMs": 17}]}))
        report = compare.compare_paths(reference, candidate, self.mask({"regions": []}))
        self.assertFalse(report["passed"])
        self.assertEqual(report["timestampMismatches"], [{"frame": 1, "referenceMs": 16, "candidateMs": 17}])


if __name__ == "__main__":
    unittest.main()
