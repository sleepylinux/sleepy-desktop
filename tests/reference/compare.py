#!/usr/bin/env python3
import argparse
import json
import pathlib
import sys

import numpy as np
from PIL import Image


def _load_mask(path):
    data = json.loads(pathlib.Path(path).read_text())
    if not isinstance(data, dict) or not isinstance(data.get("regions", []), list):
        raise ValueError("mask must be an object with a regions array")
    return data


def _bounds(entry, width, height):
    values = entry.get("bounds")
    if not isinstance(values, list) or len(values) != 4 or not all(isinstance(value, int) for value in values):
        raise ValueError("every region/surface requires integer [x,y,width,height] bounds")
    x, y, region_width, region_height = values
    if x < 0 or y < 0 or region_width < 1 or region_height < 1 or x + region_width > width or y + region_height > height:
        raise ValueError(f"bounds outside image: {values}")
    return x, y, region_width, region_height


def _compare_images(reference_path, candidate_path, mask):
    reference = np.asarray(Image.open(reference_path).convert("RGBA"), dtype=np.int16)
    candidate = np.asarray(Image.open(candidate_path).convert("RGBA"), dtype=np.int16)
    dimensions_match = reference.shape == candidate.shape
    if not dimensions_match:
        return {
            "passed": False,
            "referenceDimensions": [int(reference.shape[1]), int(reference.shape[0])],
            "candidateDimensions": [int(candidate.shape[1]), int(candidate.shape[0])],
            "differingPixelsOutsideMasks": None,
            "maskedDifferingPixels": None,
            "maximumChannelDelta": None,
            "differenceBoundsOutsideMasks": None,
            "surfaces": [],
        }

    height, width, _ = reference.shape
    channel_delta = np.abs(reference - candidate)
    different = np.any(channel_delta != 0, axis=2)
    masked = np.zeros((height, width), dtype=bool)
    for region in mask.get("regions", []):
        x, y, region_width, region_height = _bounds(region, width, height)
        masked[y:y + region_height, x:x + region_width] = True
    outside = different & ~masked
    coordinates = np.argwhere(outside)
    difference_bounds = None
    if coordinates.size:
        y_min, x_min = coordinates.min(axis=0)
        y_max, x_max = coordinates.max(axis=0)
        difference_bounds = [int(x_min), int(y_min), int(x_max - x_min + 1), int(y_max - y_min + 1)]

    surfaces = []
    surfaces_pass = True
    for surface in mask.get("surfaces", []):
        x, y, surface_width, surface_height = _bounds(surface, width, height)
        minimum = surface.get("minVisiblePixels", 1)
        if not isinstance(minimum, int) or minimum < 1:
            raise ValueError("surface minVisiblePixels must be a positive integer")
        reference_visible = int(np.count_nonzero(reference[y:y + surface_height, x:x + surface_width, 3]))
        candidate_visible = int(np.count_nonzero(candidate[y:y + surface_height, x:x + surface_width, 3]))
        surface_pass = reference_visible >= minimum and candidate_visible >= minimum
        surfaces_pass &= surface_pass
        surfaces.append({
            "name": surface.get("name", "unnamed"),
            "bounds": [x, y, surface_width, surface_height],
            "minimumVisiblePixels": minimum,
            "referenceVisiblePixels": reference_visible,
            "candidateVisiblePixels": candidate_visible,
            "passed": bool(surface_pass),
        })

    outside_count = int(np.count_nonzero(outside))
    return {
        "passed": outside_count == 0 and surfaces_pass,
        "referenceDimensions": [width, height],
        "candidateDimensions": [width, height],
        "differingPixelsOutsideMasks": outside_count,
        "maskedDifferingPixels": int(np.count_nonzero(different & masked)),
        "maximumChannelDelta": int(channel_delta.max(initial=0)),
        "differenceBoundsOutsideMasks": difference_bounds,
        "surfaces": surfaces,
    }


def _timeline(directory):
    data = json.loads((directory / "timeline.json").read_text())
    frames = data.get("frames")
    if not isinstance(frames, list):
        raise ValueError("animation timeline requires a frames array")
    for frame in frames:
        if set(frame) != {"file", "timestampMs"} or not isinstance(frame["file"], str) or not isinstance(frame["timestampMs"], int):
            raise ValueError("animation frames require exact file and integer timestampMs fields")
        if pathlib.Path(frame["file"]).name != frame["file"] or not frame["file"].endswith(".png"):
            raise ValueError("animation frame file must be a PNG basename")
    return frames


def compare_paths(reference_path, candidate_path, mask_path):
    reference_path = pathlib.Path(reference_path)
    candidate_path = pathlib.Path(candidate_path)
    mask = _load_mask(mask_path)
    if reference_path.is_dir() != candidate_path.is_dir():
        return {"passed": False, "error": "reference and candidate kinds differ"}
    if reference_path.is_file():
        return _compare_images(reference_path, candidate_path, mask)

    reference_frames = _timeline(reference_path)
    candidate_frames = _timeline(candidate_path)
    count_match = len(reference_frames) == len(candidate_frames)
    timestamp_mismatches = []
    frame_reports = []
    for index, (reference_frame, candidate_frame) in enumerate(zip(reference_frames, candidate_frames)):
        if reference_frame["timestampMs"] != candidate_frame["timestampMs"]:
            timestamp_mismatches.append({
                "frame": index,
                "referenceMs": reference_frame["timestampMs"],
                "candidateMs": candidate_frame["timestampMs"],
            })
        report = _compare_images(reference_path / reference_frame["file"], candidate_path / candidate_frame["file"], mask)
        report["frame"] = index
        frame_reports.append(report)
    return {
        "passed": count_match and not timestamp_mismatches and all(report["passed"] for report in frame_reports),
        "referenceFrameCount": len(reference_frames),
        "candidateFrameCount": len(candidate_frames),
        "timestampMismatches": timestamp_mismatches,
        "frames": frame_reports,
    }


def main():
    parser = argparse.ArgumentParser(description="Compare deterministic Sleepy shell reference pixels")
    parser.add_argument("--reference", required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--mask", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    try:
        report = compare_paths(args.reference, args.candidate, args.mask)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        report = {"passed": False, "error": str(error)}
    pathlib.Path(args.report).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    return 0 if report.get("passed") else 1


if __name__ == "__main__":
    sys.exit(main())
