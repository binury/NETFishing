#!/usr/bin/env python3
"""Export convention-named terrain chunk collections to individual GLBs.

Run through Blender rather than a standalone Python interpreter:

    blender --background terrain_chunks.blend \
      --python tools/blender/export_terrain_chunks.py -- \
      --output /path/to/terrain_chunks

Collections use ``chunk_####_description`` and contain one primary terrain
mesh named ``chunk_####``. Additional production objects may live in the same
collection; unrelated collections are ignored.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import bpy
from mathutils import Vector


CHUNK_SIZE_METERS = 10.0
DEFAULT_TOLERANCE = 0.001
COLLECTION_PATTERN = re.compile(
    r"^chunk_(?P<number>\d{4})(?:_(?P<label>[a-z0-9]+(?:_[a-z0-9]+)*))?$"
)
ALLOWED_OBJECT_TYPES = {"EMPTY", "MESH"}


class ExportValidationError(RuntimeError):
    """Raised when the source file does not satisfy the chunk convention."""


@dataclass(frozen=True)
class Bounds:
    minimum: tuple[float, float, float]
    maximum: tuple[float, float, float]

    @property
    def size(self) -> tuple[float, float, float]:
        return tuple(
            self.maximum[axis] - self.minimum[axis] for axis in range(3)
        )

    @property
    def center(self) -> tuple[float, float, float]:
        return tuple(
            (self.minimum[axis] + self.maximum[axis]) * 0.5
            for axis in range(3)
        )


@dataclass(frozen=True)
class ChunkSource:
    number: int
    stable_id: str
    label: str
    collection: bpy.types.Collection
    primary_mesh: bpy.types.Object
    objects: tuple[bpy.types.Object, ...]
    bounds: Bounds


def _parse_arguments() -> argparse.Namespace:
    script_arguments: list[str] = []
    if "--" in sys.argv:
        script_arguments = sys.argv[sys.argv.index("--") + 1 :]
    parser = argparse.ArgumentParser(
        description="Export NETfishing terrain chunk collections to GLB files."
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help="Directory that will receive chunk_####.glb and chunks.json.",
    )
    parser.add_argument(
        "--tolerance",
        type=float,
        default=DEFAULT_TOLERANCE,
        help="World-space validation tolerance in meters.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and report chunks without writing output files.",
    )
    return parser.parse_args(script_arguments)


def _close_enough(actual: float, expected: float, tolerance: float) -> bool:
    return math.isclose(actual, expected, rel_tol=0.0, abs_tol=tolerance)


def _format_vector(values: Iterable[float]) -> str:
    return "(" + ", ".join(f"{value:.4f}" for value in values) + ")"


def _world_bounds(mesh_object: bpy.types.Object) -> Bounds:
    evaluated_object = mesh_object.evaluated_get(
        bpy.context.evaluated_depsgraph_get()
    )
    world_corners = [
        evaluated_object.matrix_world @ Vector(corner)
        for corner in evaluated_object.bound_box
    ]
    minimum = tuple(
        min(corner[axis] for corner in world_corners) for axis in range(3)
    )
    maximum = tuple(
        max(corner[axis] for corner in world_corners) for axis in range(3)
    )
    return Bounds(minimum=minimum, maximum=maximum)


def _validate_transform(
    mesh_object: bpy.types.Object,
    tolerance: float,
) -> list[str]:
    problems: list[str] = []
    for axis, value in zip("XYZ", mesh_object.location):
        if not _close_enough(value, 0.0, tolerance):
            problems.append(f"location {axis} is {value:.6f}, expected 0")
    for axis, value in zip("XYZ", mesh_object.rotation_euler):
        if not _close_enough(value, 0.0, tolerance):
            problems.append(f"rotation {axis} is {value:.6f}, expected 0")
    for axis, value in zip("XYZ", mesh_object.scale):
        if not _close_enough(value, 1.0, tolerance):
            problems.append(f"scale {axis} is {value:.6f}, expected 1")
    return problems


def _validate_bounds(bounds: Bounds, tolerance: float) -> list[str]:
    problems: list[str] = []
    expected_half_size = CHUNK_SIZE_METERS * 0.5
    expected_values = {
        "minimum X": (bounds.minimum[0], -expected_half_size),
        "maximum X": (bounds.maximum[0], expected_half_size),
        "minimum Y": (bounds.minimum[1], -expected_half_size),
        "maximum Y": (bounds.maximum[1], expected_half_size),
    }
    for label, (actual, expected) in expected_values.items():
        if not _close_enough(actual, expected, tolerance):
            problems.append(f"{label} is {actual:.6f}, expected {expected:.6f}")
    return problems


def _discover_chunks(tolerance: float) -> list[ChunkSource]:
    chunks: list[ChunkSource] = []
    errors: list[str] = []
    claimed_objects: dict[str, str] = {}
    claimed_numbers: dict[int, str] = {}

    for collection in sorted(bpy.data.collections, key=lambda item: item.name):
        match = COLLECTION_PATTERN.fullmatch(collection.name)
        if match is None:
            continue

        number = int(match.group("number"))
        stable_id = f"chunk_{number:04d}"
        label = match.group("label") or ""
        if number in claimed_numbers:
            errors.append(
                f"{collection.name}: duplicates numeric ID already used by "
                f"{claimed_numbers[number]}"
            )
            continue
        claimed_numbers[number] = collection.name

        objects = tuple(sorted(collection.all_objects, key=lambda item: item.name))
        if not objects:
            errors.append(f"{collection.name}: collection is empty")
            continue

        invalid_objects = [
            item for item in objects if item.type not in ALLOWED_OBJECT_TYPES
        ]
        if invalid_objects:
            details = ", ".join(
                f"{item.name} ({item.type})" for item in invalid_objects
            )
            errors.append(
                f"{collection.name}: contains unsupported objects: {details}"
            )

        primary_matches = [
            item
            for item in objects
            if item.name == stable_id and item.type == "MESH"
        ]
        if len(primary_matches) != 1:
            errors.append(
                f"{collection.name}: expected exactly one primary mesh named "
                f"{stable_id}, found {len(primary_matches)}"
            )
            continue
        primary_mesh = primary_matches[0]

        for item in objects:
            previous_collection = claimed_objects.get(item.name)
            if previous_collection is not None:
                errors.append(
                    f"{collection.name}: object {item.name} is also exported by "
                    f"{previous_collection}"
                )
            else:
                claimed_objects[item.name] = collection.name

        transform_problems = _validate_transform(primary_mesh, tolerance)
        errors.extend(
            f"{collection.name}/{primary_mesh.name}: {problem}"
            for problem in transform_problems
        )

        bounds = _world_bounds(primary_mesh)
        bound_problems = _validate_bounds(bounds, tolerance)
        errors.extend(
            f"{collection.name}/{primary_mesh.name}: {problem}"
            for problem in bound_problems
        )

        if len(primary_mesh.data.vertices) < 3:
            errors.append(
                f"{collection.name}/{primary_mesh.name}: mesh has fewer than "
                "three vertices"
            )
        if len(primary_mesh.data.materials) == 0:
            errors.append(
                f"{collection.name}/{primary_mesh.name}: mesh has no material"
            )

        chunks.append(
            ChunkSource(
                number=number,
                stable_id=stable_id,
                label=label,
                collection=collection,
                primary_mesh=primary_mesh,
                objects=objects,
                bounds=bounds,
            )
        )

    if not chunks:
        errors.append(
            "No collections matched chunk_####_description (for example, "
            "chunk_0000_grass)."
        )
    if errors:
        raise ExportValidationError("\n".join(errors))
    return sorted(chunks, key=lambda item: item.number)


def _select_chunk(chunk: ChunkSource) -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    # Blender's selection operator can miss objects after a glTF export has
    # temporarily changed visibility/context. Set every object explicitly so
    # one chunk can never leak into a later chunk's selected-only export.
    selected_objects = set(chunk.objects)
    for item in bpy.context.view_layer.objects:
        item.select_set(item in selected_objects)
    for item in chunk.objects:
        item.hide_select = False
        item.hide_viewport = False
        item.hide_set(False)
        item.select_set(True)
    bpy.context.view_layer.objects.active = chunk.primary_mesh


def _export_chunk(chunk: ChunkSource, output_path: Path) -> None:
    _select_chunk(chunk)
    result = bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        check_existing=False,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
        export_materials="EXPORT",
        export_morph=False,
        export_normals=True,
        export_skins=False,
        export_tangents=False,
        export_texcoords=True,
        export_yup=True,
        export_extras=True,
        will_save_settings=False,
    )
    if result != {"FINISHED"}:
        raise RuntimeError(
            f"Blender failed to export {chunk.collection.name}: {result}"
        )
    _validate_exported_object_membership(chunk, output_path)


def _validate_exported_object_membership(
    chunk: ChunkSource,
    output_path: Path,
) -> None:
    """Confirm selected-only export did not leak objects from other chunks."""
    with output_path.open("rb") as source:
        header = source.read(20)
        if len(header) != 20 or header[:4] != b"glTF":
            raise RuntimeError(f"{output_path.name} is not a valid GLB file")
        json_length, json_kind = struct.unpack_from("<II", header, 12)
        if json_kind != 0x4E4F534A:
            raise RuntimeError(
                f"{output_path.name} does not begin with a GLB JSON chunk"
            )
        document = json.loads(source.read(json_length))
    exported_names = {
        str(node.get("name", ""))
        for node in document.get("nodes", [])
        if str(node.get("name", ""))
    }
    expected_names = {item.name for item in chunk.objects}
    if exported_names != expected_names:
        raise RuntimeError(
            f"{output_path.name} object membership mismatch: expected "
            f"{sorted(expected_names)}, exported {sorted(exported_names)}"
        )


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _round_vector(values: Iterable[float]) -> list[float]:
    return [round(value, 6) for value in values]


def _manifest_entry(chunk: ChunkSource, output_path: Path) -> dict[str, object]:
    return {
        "id": chunk.stable_id,
        "number": chunk.number,
        "label": chunk.label,
        "collection": chunk.collection.name,
        "primary_mesh": chunk.primary_mesh.name,
        "objects": [item.name for item in chunk.objects],
        "file": output_path.name,
        "sha256": _sha256(output_path),
        "bounds": {
            "minimum": _round_vector(chunk.bounds.minimum),
            "maximum": _round_vector(chunk.bounds.maximum),
            "size": _round_vector(chunk.bounds.size),
            "center": _round_vector(chunk.bounds.center),
        },
    }


def _run() -> int:
    arguments = _parse_arguments()
    if arguments.tolerance <= 0.0:
        raise ExportValidationError("--tolerance must be greater than zero")

    chunks = _discover_chunks(arguments.tolerance)
    print(
        f"Validated {len(chunks)} terrain chunks from "
        f"{Path(bpy.data.filepath).resolve()}"
    )
    for chunk in chunks:
        print(
            f"  {chunk.stable_id}: {chunk.label or '(no label)'} | "
            f"bounds {_format_vector(chunk.bounds.minimum)} to "
            f"{_format_vector(chunk.bounds.maximum)} | "
            f"{len(chunk.objects)} object(s)"
        )

    if arguments.dry_run:
        print("Dry run complete; no files written.")
        return 0

    output_directory = arguments.output.expanduser().resolve()
    output_directory.mkdir(parents=True, exist_ok=True)
    entries: list[dict[str, object]] = []
    expected_files: set[str] = set()
    for chunk in chunks:
        output_path = output_directory / f"{chunk.stable_id}.glb"
        _export_chunk(chunk, output_path)
        expected_files.add(output_path.name)
        entry = _manifest_entry(chunk, output_path)
        entries.append(entry)
        print(
            f"Exported {output_path.name} | {output_path.stat().st_size} bytes | "
            f"{entry['sha256']}"
        )

    manifest = {
        "format_version": 1,
        "chunk_size_meters": CHUNK_SIZE_METERS,
        "source_blend": str(Path(bpy.data.filepath).resolve()),
        "blender_version": bpy.app.version_string,
        "chunks": entries,
    }
    manifest_path = output_directory / "chunks.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    expected_files.add(manifest_path.name)

    stale_files = sorted(
        path.name
        for path in output_directory.glob("chunk_*.glb")
        if path.name not in expected_files
    )
    if stale_files:
        print(
            "WARNING: stale chunk outputs were retained: "
            + ", ".join(stale_files)
        )
    print(f"Wrote manifest {manifest_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(_run())
    except ExportValidationError as error:
        print(f"EXPORT VALIDATION FAILED:\n{error}", file=sys.stderr)
        raise SystemExit(2) from error
