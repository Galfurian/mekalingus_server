#!/usr/bin/env python3
"""Audit power-related stats for mek/item/structure JSON catalogs."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

from core import (
    audit_combat_entities,
    audit_items,
    detect_entity_kind,
    filter_entity_ids,
    load_json_file,
    merge_audits,
    parse_slot_factor_map,
    resolve_json_targets,
)


def audit_one_file(
    file_path: Path,
    kind: str,
    entity_glob: str,
    slot_factors: Dict[int, float],
) -> Tuple[Path, Dict[str, Any]]:
    payload = load_json_file(file_path)
    filtered_payload = filter_entity_ids(payload, entity_glob)

    selected_kind = kind
    if selected_kind == "auto":
        selected_kind = detect_entity_kind(file_path)

    if selected_kind == "meks" or selected_kind == "structures":
        return file_path, audit_combat_entities(
            filtered_payload,
            selected_kind,
            slot_factors,
        )
    if selected_kind == "items":
        return file_path, audit_items(filtered_payload, slot_factors)

    raise ValueError("Unable to determine entity kind for %s" % file_path)


def print_human_report(results: List[Dict[str, Any]], include_merged: bool) -> None:
    for entry in results:
        print("\n%s" % entry["file"])
        print("  kind: %s" % entry["report"]["kind"])
        print("  entity_count: %d" % entry["report"]["entity_count"])
        for key, value in entry["report"].items():
            if key in ("kind", "entity_count", "_raw_values"):
                continue
            print(
                "  %s: count=%d min=%s max=%s mean=%s median=%s"
                % (
                    key,
                    int(value["count"]),
                    value["min"],
                    value["max"],
                    value["mean"],
                    value["median"],
                )
            )

    if include_merged:
        print("\nMerged summary included above in JSON mode only when --json is used.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Audit power-related metrics for mek/item/structure catalogs.",
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
        help="Entity kind to parse. Use auto to infer from path.",
    )
    parser.add_argument(
        "--entity-glob",
        default="*",
        help="Filter entity IDs by glob (e.g. lmek00*).",
    )
    parser.add_argument(
        "--recursive",
        action="store_true",
        help="When target is a folder, include nested JSON files.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON report.",
    )
    parser.add_argument(
        "--include-merged",
        action="store_true",
        help="Include merged/aggregate stats across all processed files.",
    )
    parser.add_argument(
        "--slot-factors",
        default="",
        help=(
            "Slot weighting map as CSV, e.g. "
            "small=0.85,medium=1.0,large=1.2,utility=0.75"
        ),
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

    targets = resolve_json_targets(args.targets, recursive=args.recursive)
    if not targets:
        print("No JSON files matched target(s).", file=sys.stderr)
        return 1

    results: List[Dict[str, Any]] = []
    reports_for_merge: Dict[str, List[Dict[str, Any]]] = {}

    for file_path in targets:
        try:
            selected_kind = (
                args.kind if args.kind != "auto" else detect_entity_kind(file_path)
            )
            if selected_kind not in ("meks", "items", "structures"):
                print(
                    "Skipping %s: could not detect kind (--kind auto)." % file_path,
                    file=sys.stderr,
                )
                continue

            _, report = audit_one_file(
                file_path,
                selected_kind,
                args.entity_glob,
                slot_factors,
            )
            reports_for_merge.setdefault(selected_kind, []).append(report)
            results.append({"file": str(file_path), "report": report})
        except Exception as exc:  # pragma: no cover
            print("Error auditing %s: %s" % (file_path, exc), file=sys.stderr)

    if args.include_merged and reports_for_merge:
        for merge_kind, reports in reports_for_merge.items():
            merged = merge_audits(reports, merge_kind)
            results.append({"file": "<merged:%s>" % merge_kind, "report": merged})

    # Remove internal raw values before final output.
    for entry in results:
        entry["report"].pop("_raw_values", None)

    if args.json:
        print(json.dumps(results, indent=2, ensure_ascii=False))
    else:
        print_human_report(results, args.include_merged)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
