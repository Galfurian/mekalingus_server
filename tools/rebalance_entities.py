#!/usr/bin/env python3
"""Rebalance power-related stats with dry-run and in-place modes."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from core import (
    apply_rounding,
    clamp_optional,
    detect_entity_kind,
    filter_entity_ids,
    load_json_file,
    resolve_json_targets,
    write_json_file,
)


def _transform_value(
    old_value: float,
    scale: float,
    offset: float,
    min_value: Optional[float],
    max_value: Optional[float],
    rounding: str,
) -> float:
    updated = (old_value * scale) + offset
    updated = clamp_optional(updated, min_value, max_value)
    updated = apply_rounding(updated, rounding)
    return updated


def _diff_value(old_value: Any, new_value: Any) -> bool:
    return old_value != new_value


def rebalance_mek_or_structure_entity(
    entity: Dict[str, Any],
    power_scale: float,
    power_offset: float,
    power_gen_scale: float,
    power_gen_offset: float,
    power_gen_ratio: Optional[float],
    power_min: Optional[float],
    power_max: Optional[float],
    power_gen_min: Optional[float],
    power_gen_max: Optional[float],
    rounding: str,
) -> Dict[str, Dict[str, Any]]:
    changes: Dict[str, Dict[str, Any]] = {}

    old_power = float(entity.get("power", 0))
    new_power = _transform_value(
        old_power,
        power_scale,
        power_offset,
        power_min,
        power_max,
        rounding,
    )

    if _diff_value(old_power, new_power):
        changes["power"] = {"old": old_power, "new": new_power}
        entity["power"] = int(new_power) if float(new_power).is_integer() else new_power

    old_power_generation = float(entity.get("power_generation", 0))
    if power_gen_ratio is not None:
        derived_generation = clamp_optional(
            float(entity["power"]) * power_gen_ratio,
            power_gen_min,
            power_gen_max,
        )
        new_power_generation = apply_rounding(derived_generation, rounding)
    else:
        new_power_generation = _transform_value(
            old_power_generation,
            power_gen_scale,
            power_gen_offset,
            power_gen_min,
            power_gen_max,
            rounding,
        )

    if _diff_value(old_power_generation, new_power_generation):
        changes["power_generation"] = {
            "old": old_power_generation,
            "new": new_power_generation,
        }
        entity["power_generation"] = (
            int(new_power_generation)
            if float(new_power_generation).is_integer()
            else new_power_generation
        )

    return changes


def rebalance_item_entity(
    entity: Dict[str, Any],
    base_power_scale: float,
    base_power_offset: float,
    base_power_min: Optional[float],
    base_power_max: Optional[float],
    module_power_scale: float,
    module_power_offset: float,
    module_power_min: Optional[float],
    module_power_max: Optional[float],
    module_glob: str,
    rounding: str,
) -> Dict[str, Dict[str, Any]]:
    import fnmatch

    changes: Dict[str, Dict[str, Any]] = {}

    old_base = float(entity.get("base_power_usage", 0))
    new_base = _transform_value(
        old_base,
        base_power_scale,
        base_power_offset,
        base_power_min,
        base_power_max,
        rounding,
    )
    if _diff_value(old_base, new_base):
        changes["base_power_usage"] = {"old": old_base, "new": new_base}
        entity["base_power_usage"] = int(new_base) if float(new_base).is_integer() else new_base

    modules = entity.get("modules", [])
    for index, module in enumerate(modules):
        module_name = str(module.get("name", "module_%d" % index))
        if not fnmatch.fnmatch(module_name, module_glob):
            continue

        old_module_power = float(module.get("power_on_use", 0))
        new_module_power = _transform_value(
            old_module_power,
            module_power_scale,
            module_power_offset,
            module_power_min,
            module_power_max,
            rounding,
        )
        if _diff_value(old_module_power, new_module_power):
            changes["modules.%d.power_on_use" % index] = {
                "module": module_name,
                "old": old_module_power,
                "new": new_module_power,
            }
            module["power_on_use"] = (
                int(new_module_power)
                if float(new_module_power).is_integer()
                else new_module_power
            )

    return changes


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Rebalance power-related fields in mek/item/structure catalogs.",
    )
    parser.add_argument(
        "targets",
        nargs="+",
        help="One or more targets: file, folder, glob, or recursive glob.",
    )
    parser.add_argument(
        "--kind",
        choices=["meks", "items", "structures", "auto"],
        default="auto",
        help="Entity kind to process. Use auto to infer from path.",
    )
    parser.add_argument(
        "--entity-glob",
        default="*",
        help="Filter entity IDs by glob.",
    )
    parser.add_argument(
        "--module-glob",
        default="*",
        help="For items, filter module names by glob.",
    )
    parser.add_argument(
        "--recursive",
        action="store_true",
        help="When target is a folder, include nested JSON files.",
    )

    # Mek / structure transforms.
    parser.add_argument("--power-scale", type=float, default=1.0)
    parser.add_argument("--power-offset", type=float, default=0.0)
    parser.add_argument("--power-gen-scale", type=float, default=1.0)
    parser.add_argument("--power-gen-offset", type=float, default=0.0)
    parser.add_argument(
        "--power-gen-ratio",
        type=float,
        default=None,
        help="If provided, power_generation = power * ratio after power transform.",
    )
    parser.add_argument("--power-min", type=float, default=None)
    parser.add_argument("--power-max", type=float, default=None)
    parser.add_argument("--power-gen-min", type=float, default=None)
    parser.add_argument("--power-gen-max", type=float, default=None)

    # Item transforms.
    parser.add_argument("--base-power-scale", type=float, default=1.0)
    parser.add_argument("--base-power-offset", type=float, default=0.0)
    parser.add_argument("--base-power-min", type=float, default=None)
    parser.add_argument("--base-power-max", type=float, default=None)
    parser.add_argument("--module-power-scale", type=float, default=1.0)
    parser.add_argument("--module-power-offset", type=float, default=0.0)
    parser.add_argument("--module-power-min", type=float, default=None)
    parser.add_argument("--module-power-max", type=float, default=None)

    parser.add_argument(
        "--rounding",
        choices=["none", "int", "floor", "ceil"],
        default="int",
        help="Rounding mode after transform and clamp.",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Apply changes to files. Default is dry run.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON summary.",
    )
    parser.add_argument(
        "--max-preview",
        type=int,
        default=25,
        help="Max change rows printed in human mode.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    targets = resolve_json_targets(args.targets, recursive=args.recursive)
    if not targets:
        print("No JSON files matched target(s).", file=sys.stderr)
        return 1

    all_changes: List[Dict[str, Any]] = []

    for file_path in targets:
        try:
            payload = load_json_file(file_path)
            filtered_ids = set(filter_entity_ids(payload, args.entity_glob).keys())

            selected_kind = args.kind if args.kind != "auto" else detect_entity_kind(file_path)
            if selected_kind not in ("meks", "items", "structures"):
                print("Skipping %s: cannot determine kind." % file_path, file=sys.stderr)
                continue

            file_changes: Dict[str, Any] = {"file": str(file_path), "kind": selected_kind, "entities": {}}

            for entity_id, entity_data in payload.items():
                if entity_id not in filtered_ids:
                    continue

                entity_changes: Dict[str, Dict[str, Any]] = {}
                if selected_kind in ("meks", "structures"):
                    entity_changes = rebalance_mek_or_structure_entity(
                        entity_data,
                        args.power_scale,
                        args.power_offset,
                        args.power_gen_scale,
                        args.power_gen_offset,
                        args.power_gen_ratio,
                        args.power_min,
                        args.power_max,
                        args.power_gen_min,
                        args.power_gen_max,
                        args.rounding,
                    )
                elif selected_kind == "items":
                    entity_changes = rebalance_item_entity(
                        entity_data,
                        args.base_power_scale,
                        args.base_power_offset,
                        args.base_power_min,
                        args.base_power_max,
                        args.module_power_scale,
                        args.module_power_offset,
                        args.module_power_min,
                        args.module_power_max,
                        args.module_glob,
                        args.rounding,
                    )

                if entity_changes:
                    file_changes["entities"][entity_id] = entity_changes

            if file_changes["entities"]:
                all_changes.append(file_changes)
                if args.in_place:
                    write_json_file(file_path, payload)
        except Exception as exc:  # pragma: no cover
            print("Error processing %s: %s" % (file_path, exc), file=sys.stderr)

    if args.json:
        print(json.dumps(all_changes, indent=2, ensure_ascii=False))
    else:
        dry_run = not args.in_place
        print("Mode: %s" % ("DRY RUN" if dry_run else "IN PLACE"))

        preview_count = 0
        total_entity_changes = 0
        for file_change in all_changes:
            print("\n%s (%s)" % (file_change["file"], file_change["kind"]))
            for entity_id, changes in file_change["entities"].items():
                total_entity_changes += 1
                if preview_count >= args.max_preview:
                    continue
                print("  %s" % entity_id)
                for field_name, field_change in changes.items():
                    print(
                        "    %s: %s -> %s"
                        % (field_name, field_change["old"], field_change["new"])
                    )
                preview_count += 1

        if not all_changes:
            print("No changes required.")
        else:
            print("\nChanged entities: %d" % total_entity_changes)
            if dry_run:
                print("No files modified. Re-run with --in-place to apply.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
