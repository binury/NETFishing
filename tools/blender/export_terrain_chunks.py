#!/usr/bin/env python3
"""Export convention-named terrain chunk collections to individual GLBs.

Run through Blender rather than a standalone Python interpreter:

    blender --background terrain_chunks.blend \
      --python tools/blender/export_terrain_chunks.py -- \
      --output /path/to/terrain_chunks

Collections use ``chunk_####_description`` and contain one primary terrain
mesh named ``chunk_####``. Additional production objects may live in the same
collection. Reusable procedural props use individual ``prop_description``
mesh objects. They may be arranged anywhere in the source file because each
object's authored origin becomes the exported runtime anchor. A same-named
``prop_description`` collection remains supported for multi-object props.
Unrelated objects and collections are ignored.
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
# Match the runtime boundary analyzer's five-millimeter authoring tolerance.
DEFAULT_TOLERANCE = 0.005
COLLECTION_PATTERN = re.compile(
    r"^chunk_(?P<number>\d{4})(?:_(?P<label>[a-z0-9]+(?:_[a-z0-9]+)*))?$"
)
PROP_COLLECTION_PATTERN = re.compile(
    r"^prop_(?P<label>[a-z0-9]+(?:_[a-z0-9]+)*)$"
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


@dataclass(frozen=True)
class PropSource:
    stable_id: str
    label: str
    source_kind: str
    source_name: str
    collection: bpy.types.Collection
    primary_mesh: bpy.types.Object
    objects: tuple[bpy.types.Object, ...]
    bounds: Bounds
    anchor_world: tuple[float, float, float]


ExportSource = ChunkSource | PropSource


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
        help=(
            "Directory that will receive chunk_####.glb, prop_*.glb, and "
            "chunks.json."
        ),
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


def _validate_bounds(
    bounds: Bounds,
    tolerance: float,
    allow_open_east_edge: bool = False,
    allow_open_south_edge: bool = False,
) -> list[str]:
    problems: list[str] = []
    expected_half_size = CHUNK_SIZE_METERS * 0.5
    expected_values = {
        "minimum X": (bounds.minimum[0], -expected_half_size),
        "maximum Y": (bounds.maximum[1], expected_half_size),
    }
    if not allow_open_east_edge:
        expected_values["maximum X"] = (
            bounds.maximum[0],
            expected_half_size,
        )
    if not allow_open_south_edge:
        expected_values["minimum Y"] = (
            bounds.minimum[1],
            -expected_half_size,
        )
    for label, (actual, expected) in expected_values.items():
        if not _close_enough(actual, expected, tolerance):
            problems.append(f"{label} is {actual:.6f}, expected {expected:.6f}")
    if (
        allow_open_east_edge
        and bounds.maximum[0] > expected_half_size + tolerance
    ):
        problems.append(
            f"maximum X is {bounds.maximum[0]:.6f}, expected no greater than "
            f"{expected_half_size:.6f}"
        )
    if (
        allow_open_south_edge
        and bounds.minimum[1] < -expected_half_size - tolerance
    ):
        problems.append(
            f"minimum Y is {bounds.minimum[1]:.6f}, expected no less than "
            f"{-expected_half_size:.6f}"
        )
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
        # Coastline meshes may intentionally stop before the positive-X edge,
        # leaving the surrounding ocean visible. Positive X is the canonical
        # authored ocean direction; Godot supplies the quarter-turn variants.
        # Elevated inland cliff overlays also stop at their downhill edge,
        # while second-tier sea pieces carry that edge down to ocean depth.
        layered_cliff = "cliff_2" in label
        allow_open_east_edge = (
            "ocean_edge" in label
            or "sea_edge" in label
            or "sea_corner" in label
            or layered_cliff
        )
        # Corner pieces additionally leave canonical negative Y open. Their
        # two marked outer edges rotate together at runtime.
        allow_open_south_edge = (
            "ocean_edge_corner" in label
            or "sea_corner" in label
            or (layered_cliff and "corner" in label)
        )
        bound_problems = _validate_bounds(
            bounds,
            tolerance,
            allow_open_east_edge=allow_open_east_edge,
            allow_open_south_edge=allow_open_south_edge,
        )
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


def _validate_prop_bounds(bounds: Bounds, tolerance: float) -> list[str]:
    problems: list[str] = []
    for axis, size in zip("XYZ", bounds.size):
        if size <= tolerance:
            problems.append(f"bounds size {axis} is {size:.6f}, expected positive")
    return problems


def _rebased_prop_bounds(
    mesh_objects: list[bpy.types.Object],
    anchor_world: Vector,
) -> Bounds:
    corners: list[Vector] = []
    dependency_graph = bpy.context.evaluated_depsgraph_get()
    for mesh_object in mesh_objects:
        evaluated_object = mesh_object.evaluated_get(dependency_graph)
        corners.extend(
            evaluated_object.matrix_world @ Vector(corner) - anchor_world
            for corner in evaluated_object.bound_box
        )
    minimum = tuple(
        min(corner[axis] for corner in corners) for axis in range(3)
    )
    maximum = tuple(
        max(corner[axis] for corner in corners) for axis in range(3)
    )
    return Bounds(minimum=minimum, maximum=maximum)


def _prop_transform_problems(
    source_objects: tuple[bpy.types.Object, ...],
    tolerance: float,
) -> list[str]:
    problems: list[str] = []
    source_set = set(source_objects)
    for item in source_objects:
        if item.parent is not None and item.parent not in source_set:
            problems.append(
                f"{item.name} is parented outside its exported prop source"
            )
        for label, values in (
            ("location", item.location),
            ("rotation", item.rotation_euler),
            ("scale", item.scale),
        ):
            if not all(math.isfinite(value) for value in values):
                problems.append(f"{item.name} has a non-finite {label}")
        for axis, value in zip("XYZ", item.scale):
            if abs(value) <= tolerance:
                problems.append(
                    f"{item.name} scale {axis} is {value:.6f}, expected nonzero"
                )
    return problems


def _make_prop_source(
    stable_id: str,
    label: str,
    source_kind: str,
    source_name: str,
    collection: bpy.types.Collection,
    objects: tuple[bpy.types.Object, ...],
    tolerance: float,
) -> tuple[PropSource | None, list[str]]:
    errors: list[str] = []
    invalid_objects = [
        item for item in objects if item.type not in ALLOWED_OBJECT_TYPES
    ]
    if invalid_objects:
        details = ", ".join(
            f"{item.name} ({item.type})" for item in invalid_objects
        )
        errors.append(f"{source_name}: contains unsupported objects: {details}")

    mesh_objects = [item for item in objects if item.type == "MESH"]
    named_meshes = [item for item in mesh_objects if item.name == stable_id]
    if len(named_meshes) == 1:
        primary_mesh = named_meshes[0]
    elif len(mesh_objects) == 1:
        primary_mesh = mesh_objects[0]
    else:
        errors.append(
            f"{source_name}: expected one mesh (preferably named "
            f"{stable_id}), found {len(mesh_objects)}"
        )
        return None, errors

    errors.extend(
        f"{source_name}: {problem}"
        for problem in _prop_transform_problems(objects, tolerance)
    )
    anchor_vector = primary_mesh.matrix_world.translation.copy()
    bounds = _rebased_prop_bounds(mesh_objects, anchor_vector)
    errors.extend(
        f"{source_name}/{primary_mesh.name}: {problem}"
        for problem in _validate_prop_bounds(bounds, tolerance)
    )
    for mesh_object in mesh_objects:
        if len(mesh_object.data.vertices) < 3:
            errors.append(
                f"{source_name}/{mesh_object.name}: has fewer than three vertices"
            )
        if len(mesh_object.data.materials) == 0:
            errors.append(
                f"{source_name}/{mesh_object.name}: has no material"
            )

    return (
        PropSource(
            stable_id=stable_id,
            label=label,
            source_kind=source_kind,
            source_name=source_name,
            collection=collection,
            primary_mesh=primary_mesh,
            objects=objects,
            bounds=bounds,
            anchor_world=tuple(anchor_vector),
        ),
        errors,
    )


def _discover_props(tolerance: float) -> list[PropSource]:
    props: list[PropSource] = []
    errors: list[str] = []
    claimed_objects: dict[int, str] = {}
    claimed_ids: dict[str, str] = {}

    for collection in sorted(bpy.data.collections, key=lambda item: item.name):
        match = PROP_COLLECTION_PATTERN.fullmatch(collection.name)
        if match is None:
            continue
        stable_id = collection.name
        label = match.group("label")
        objects = tuple(sorted(collection.all_objects, key=lambda item: item.name))
        if not objects:
            errors.append(f"{collection.name}: collection is empty")
            continue
        for item in objects:
            object_key = item.as_pointer()
            previous_source = claimed_objects.get(object_key)
            if previous_source is not None:
                errors.append(
                    f"{collection.name}: object {item.name} is also exported by "
                    f"{previous_source}"
                )
            else:
                claimed_objects[object_key] = collection.name
        prop, source_errors = _make_prop_source(
            stable_id,
            label,
            "collection",
            collection.name,
            collection,
            objects,
            tolerance,
        )
        errors.extend(source_errors)
        if prop is not None:
            props.append(prop)
            claimed_ids[stable_id] = collection.name

    for item in sorted(bpy.data.objects, key=lambda value: value.name):
        match = PROP_COLLECTION_PATTERN.fullmatch(item.name)
        if match is None or item.as_pointer() in claimed_objects:
            continue
        stable_id = item.name
        if stable_id in claimed_ids:
            errors.append(
                f"{item.name}: duplicates prop ID already used by "
                f"{claimed_ids[stable_id]}"
            )
            continue
        if item.type != "MESH":
            errors.append(f"{item.name}: prop object must be a mesh")
            continue
        collections = sorted(item.users_collection, key=lambda value: value.name)
        if not collections:
            errors.append(f"{item.name}: prop object belongs to no collection")
            continue
        prop, source_errors = _make_prop_source(
            stable_id,
            match.group("label"),
            "object",
            item.name,
            collections[0],
            (item,),
            tolerance,
        )
        errors.extend(source_errors)
        if prop is not None:
            props.append(prop)
            claimed_ids[stable_id] = item.name
            claimed_objects[item.as_pointer()] = item.name

    if errors:
        raise ExportValidationError("\n".join(errors))
    return sorted(props, key=lambda item: item.stable_id)


def _validate_distinct_source_membership(
    chunks: list[ChunkSource],
    props: list[PropSource],
) -> None:
    claimed_objects: dict[int, str] = {}
    errors: list[str] = []
    for source in [*chunks, *props]:
        source_name = (
            source.collection.name
            if isinstance(source, ChunkSource)
            else source.source_name
        )
        for item in source.objects:
            object_key = item.as_pointer()
            previous_source = claimed_objects.get(object_key)
            if previous_source is not None:
                errors.append(
                    f"{source_name}: object {item.name} is also exported by "
                    f"{previous_source}"
                )
            else:
                claimed_objects[object_key] = source_name
    if errors:
        raise ExportValidationError("\n".join(errors))


def _select_source(source: ExportSource) -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    # Blender's selection operator can miss objects after a glTF export has
    # temporarily changed visibility/context. Set every object explicitly so
    # one chunk can never leak into a later chunk's selected-only export.
    selected_objects = set(source.objects)
    for item in bpy.context.view_layer.objects:
        item.select_set(item in selected_objects)
    for item in source.objects:
        item.hide_select = False
        item.hide_viewport = False
        item.hide_set(False)
        item.select_set(True)
    bpy.context.view_layer.objects.active = source.primary_mesh


def _export_source(source: ExportSource, output_path: Path) -> None:
    _select_source(source)
    saved_root_matrices: dict[bpy.types.Object, object] = {}
    if isinstance(source, PropSource):
        source_objects = set(source.objects)
        anchor = Vector(source.anchor_world)
        for item in source.objects:
            if item.parent in source_objects:
                continue
            saved_root_matrices[item] = item.matrix_world.copy()
            rebased_matrix = item.matrix_world.copy()
            rebased_matrix.translation -= anchor
            item.matrix_world = rebased_matrix
        bpy.context.view_layer.update()

    try:
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
    finally:
        for item, matrix in saved_root_matrices.items():
            item.matrix_world = matrix
        if saved_root_matrices:
            bpy.context.view_layer.update()
    if result != {"FINISHED"}:
        source_name = (
            source.collection.name
            if isinstance(source, ChunkSource)
            else source.source_name
        )
        raise RuntimeError(
            f"Blender failed to export {source_name}: {result}"
        )
    _validate_exported_object_membership(source, output_path)


def _validate_exported_object_membership(
    source: ExportSource,
    output_path: Path,
) -> None:
    """Confirm selected-only export contains exactly the intended objects."""
    with output_path.open("rb") as binary_file:
        header = binary_file.read(20)
        if len(header) != 20 or header[:4] != b"glTF":
            raise RuntimeError(f"{output_path.name} is not a valid GLB file")
        json_length, json_kind = struct.unpack_from("<II", header, 12)
        if json_kind != 0x4E4F534A:
            raise RuntimeError(
                f"{output_path.name} does not begin with a GLB JSON chunk"
            )
        document = json.loads(binary_file.read(json_length))
    exported_names = {
        str(node.get("name", ""))
        for node in document.get("nodes", [])
        if str(node.get("name", ""))
    }
    expected_names = {item.name for item in source.objects}
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


def _prop_manifest_entry(
    prop: PropSource,
    output_path: Path,
) -> dict[str, object]:
    return {
        "id": prop.stable_id,
        "label": prop.label,
        "source_kind": prop.source_kind,
        "source_name": prop.source_name,
        "collection": prop.collection.name,
        "primary_mesh": prop.primary_mesh.name,
        "objects": [item.name for item in prop.objects],
        "source_anchor_world": _round_vector(prop.anchor_world),
        "file": output_path.name,
        "sha256": _sha256(output_path),
        "bounds": {
            "minimum": _round_vector(prop.bounds.minimum),
            "maximum": _round_vector(prop.bounds.maximum),
            "size": _round_vector(prop.bounds.size),
            "center": _round_vector(prop.bounds.center),
        },
    }


def _run() -> int:
    arguments = _parse_arguments()
    if arguments.tolerance <= 0.0:
        raise ExportValidationError("--tolerance must be greater than zero")

    chunks = _discover_chunks(arguments.tolerance)
    props = _discover_props(arguments.tolerance)
    _validate_distinct_source_membership(chunks, props)
    print(
        f"Validated {len(chunks)} terrain chunks and {len(props)} reusable "
        f"props from "
        f"{Path(bpy.data.filepath).resolve()}"
    )
    for chunk in chunks:
        print(
            f"  {chunk.stable_id}: {chunk.label or '(no label)'} | "
            f"bounds {_format_vector(chunk.bounds.minimum)} to "
            f"{_format_vector(chunk.bounds.maximum)} | "
            f"{len(chunk.objects)} object(s)"
        )
    for prop in props:
        print(
            f"  {prop.stable_id}: reusable {prop.source_kind} prop | bounds "
            f"{_format_vector(prop.bounds.minimum)} to "
            f"{_format_vector(prop.bounds.maximum)} | "
            f"{len(prop.objects)} object(s)"
        )

    if arguments.dry_run:
        print("Dry run complete; no files written.")
        return 0

    output_directory = arguments.output.expanduser().resolve()
    output_directory.mkdir(parents=True, exist_ok=True)
    entries: list[dict[str, object]] = []
    prop_entries: list[dict[str, object]] = []
    expected_files: set[str] = set()
    for chunk in chunks:
        output_path = output_directory / f"{chunk.stable_id}.glb"
        _export_source(chunk, output_path)
        expected_files.add(output_path.name)
        entry = _manifest_entry(chunk, output_path)
        entries.append(entry)
        print(
            f"Exported {output_path.name} | {output_path.stat().st_size} bytes | "
            f"{entry['sha256']}"
        )

    for prop in props:
        output_path = output_directory / f"{prop.stable_id}.glb"
        _export_source(prop, output_path)
        expected_files.add(output_path.name)
        entry = _prop_manifest_entry(prop, output_path)
        prop_entries.append(entry)
        print(
            f"Exported {output_path.name} | {output_path.stat().st_size} bytes | "
            f"{entry['sha256']}"
        )

    manifest = {
        "format_version": 2,
        "chunk_size_meters": CHUNK_SIZE_METERS,
        "source_blend": str(Path(bpy.data.filepath).resolve()),
        "blender_version": bpy.app.version_string,
        "chunks": entries,
        "props": prop_entries,
    }
    manifest_path = output_directory / "chunks.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    expected_files.add(manifest_path.name)

    stale_files = sorted({
        path.name
        for pattern in ("chunk_*.glb", "prop_*.glb")
        for path in output_directory.glob(pattern)
        if path.name not in expected_files
    })
    if stale_files:
        print(
            "WARNING: stale generated-world outputs were retained: "
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
