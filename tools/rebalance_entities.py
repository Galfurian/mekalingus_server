#!/usr/bin/env python3
"""Rebalance power-related stats with dry-run and in-place modes."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any, Dict, List, Optional

from core import (
    detect_entity_kind,
    filter_entity_ids,
    load_json_file,
    parse_slot_factor_map,
    rebalance_item_entity,
    rebalance_mek_or_structure_entity,
    resolve_json_targets,
    write_json_file,
)


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
    parser.add_argument(
        "--power-gen-ratio-blend",
        type=float,
        default=1.0,
        help=(
            "Blend factor for --power-gen-ratio in [0,1]. "
            "0 keeps existing per-mek ratio spread; 1 fully normalizes to target ratio."
        ),
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
        "--turn-budget",
        type=float,
        default=None,
        help=(
            "Optional per-turn budget reference for items. "
            "Used with --module-budget-share to cap base + one module draw."
        ),
    )
    parser.add_argument(
        "--module-budget-share",
        type=float,
        default=None,
        help=(
            "If set with --turn-budget, enforce "
            "base_power_usage + module_power_on_use <= turn_budget * share * slot_factor."
        ),
    )
    parser.add_argument(
        "--slot-factors",
        default="",
        help=(
            "Slot weighting map as CSV, e.g. "
            "small=0.85,medium=1.0,large=1.2,utility=0.75"
        ),
    )

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

    try:
        slot_factors = parse_slot_factor_map(args.slot_factors)
    except ValueError as exc:
        print("Invalid --slot-factors: %s" % exc, file=sys.stderr)
        return 2

    if args.power_gen_ratio_blend < 0.0 or args.power_gen_ratio_blend > 1.0:
        print("--power-gen-ratio-blend must be in [0, 1].", file=sys.stderr)
        return 2

    if args.module_budget_share is not None and args.module_budget_share < 0.0:
        print("--module-budget-share must be >= 0.", file=sys.stderr)
        return 2

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
                        slot_factors,
                        args.power_gen_ratio_blend,
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
                        slot_factors,
                        args.turn_budget,
                        args.module_budget_share,
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
