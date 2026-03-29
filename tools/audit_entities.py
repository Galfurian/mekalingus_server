#!/usr/bin/env python3
"""Audit power-related stats for mek/item/structure JSON catalogs."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

from core import (
    compute_numeric_stats,
    detect_entity_kind,
    filter_entity_ids,
    load_json_file,
    parse_item_catalog,
    parse_mek_catalog,
    parse_structure_catalog,
    resolve_json_targets,
)


def _stats_to_dict(stats) -> Dict[str, float]:
    return {
        "count": stats.count,
        "min": round(stats.min_value, 3),
        "max": round(stats.max_value, 3),
        "mean": round(stats.mean, 3),
        "median": round(stats.median, 3),
    }


def audit_combat_entities(
    payload: Dict[str, Any], selected_kind: str
) -> Dict[str, Any]:
    if selected_kind == "meks":
        catalog = parse_mek_catalog(payload)
    elif selected_kind == "structures":
        catalog = parse_structure_catalog(payload)
    else:
        raise ValueError(f"Unsupported entity kind: {selected_kind}")

    health_values = [float(spec.health) for spec in catalog.values()]
    health_gen_values = [float(spec.health_generation) for spec in catalog.values()]
    health_gen_ratio_values = [
        (float(spec.health_generation) / float(spec.health))
        for spec in catalog.values()
        if spec.health > 0
    ]
    armor_values = [float(spec.armor) for spec in catalog.values()]
    armor_gen_values = [float(spec.armor_generation) for spec in catalog.values()]
    armor_gen_ratio_values = [
        (float(spec.armor_generation) / float(spec.armor))
        for spec in catalog.values()
        if spec.armor > 0
    ]
    shield_values = [float(spec.shield) for spec in catalog.values()]
    shield_gen_values = [float(spec.shield_generation) for spec in catalog.values()]
    shield_gen_ratio_values = [
        (float(spec.shield_generation) / float(spec.shield))
        for spec in catalog.values()
        if spec.shield > 0
    ]
    power_values = [float(spec.power) for spec in catalog.values()]
    regen_values = [float(spec.power_generation) for spec in catalog.values()]
    regen_ratio_values = [
        (float(spec.power_generation) / float(spec.power))
        for spec in catalog.values()
        if spec.power > 0
    ]

    return {
        "kind": "meks",
        "entity_count": len(catalog),
        "health": _stats_to_dict(compute_numeric_stats(health_values)),
        "health_generation": _stats_to_dict(compute_numeric_stats(health_gen_values)),
        "health_generation_to_health_ratio": _stats_to_dict(
            compute_numeric_stats(health_gen_ratio_values)
        ),
        "armor": _stats_to_dict(compute_numeric_stats(armor_values)),
        "armor_generation": _stats_to_dict(compute_numeric_stats(armor_gen_values)),
        "armor_generation_to_armor_ratio": _stats_to_dict(
            compute_numeric_stats(armor_gen_ratio_values)
        ),
        "shield": _stats_to_dict(compute_numeric_stats(shield_values)),
        "shield_generation": _stats_to_dict(compute_numeric_stats(shield_gen_values)),
        "shield_generation_to_shield_ratio": _stats_to_dict(
            compute_numeric_stats(shield_gen_ratio_values)
        ),
        "power": _stats_to_dict(compute_numeric_stats(power_values)),
        "power_generation": _stats_to_dict(compute_numeric_stats(regen_values)),
        "power_generation_to_power_ratio": _stats_to_dict(
            compute_numeric_stats(regen_ratio_values)
        ),
    }


def audit_items(payload: Dict[str, Any]) -> Dict[str, Any]:
    catalog = parse_item_catalog(payload)

    base_power_values: List[float] = []
    module_power_values: List[float] = []
    module_repeats_values: List[float] = []

    for spec in catalog.values():
        base_power_values.append(float(spec.base_power_usage))
        for module in spec.modules:
            module_power_values.append(float(module.power_on_use))
            module_repeats_values.append(
                float(module.repeats if module.repeats is not None else 1)
            )

    return {
        "kind": "items",
        "entity_count": len(catalog),
        "base_power_usage": _stats_to_dict(compute_numeric_stats(base_power_values)),
        "module_power_on_use": _stats_to_dict(
            compute_numeric_stats(module_power_values)
        ),
        "module_repeats": _stats_to_dict(compute_numeric_stats(module_repeats_values)),
    }


def audit_one_file(
    file_path: Path, kind: str, entity_glob: str
) -> Tuple[Path, Dict[str, Any]]:
    payload = load_json_file(file_path)
    filtered_payload = filter_entity_ids(payload, entity_glob)

    selected_kind = kind
    if selected_kind == "auto":
        selected_kind = detect_entity_kind(file_path)

    if selected_kind == "meks" or selected_kind == "structures":
        return file_path, audit_combat_entities(filtered_payload, selected_kind)
    if selected_kind == "items":
        return file_path, audit_items(filtered_payload)

    raise ValueError("Unable to determine entity kind for %s" % file_path)


def merge_audits(audits: List[Dict[str, Any]], kind: str) -> Dict[str, Any]:
    merged_payload: Dict[str, Any] = {}

    if kind in ("meks", "structures"):
        merged_payload["kind"] = "%s:merged" % kind
        merged_payload["entity_count"] = sum(a["entity_count"] for a in audits)

        def gather(metric: str) -> List[float]:
            values: List[float] = []
            for report in audits:
                values.extend(report.get("_raw_values", {}).get(metric, []))
            return values

        power = gather("power")
        regen = gather("power_generation")
        ratio = gather("ratio")

        merged_payload["power"] = _stats_to_dict(compute_numeric_stats(power))
        merged_payload["power_generation"] = _stats_to_dict(
            compute_numeric_stats(regen)
        )
        merged_payload["power_generation_to_power_ratio"] = _stats_to_dict(
            compute_numeric_stats(ratio)
        )
        return merged_payload

    if kind == "items":
        merged_payload["kind"] = "items:merged"
        merged_payload["entity_count"] = sum(a["entity_count"] for a in audits)

        def gather(metric: str) -> List[float]:
            values: List[float] = []
            for report in audits:
                values.extend(report.get("_raw_values", {}).get(metric, []))
            return values

        base = gather("base_power_usage")
        module_power = gather("module_power_on_use")
        module_repeats = gather("module_repeats")

        merged_payload["base_power_usage"] = _stats_to_dict(compute_numeric_stats(base))
        merged_payload["module_power_on_use"] = _stats_to_dict(
            compute_numeric_stats(module_power)
        )
        merged_payload["module_repeats"] = _stats_to_dict(
            compute_numeric_stats(module_repeats)
        )
        return merged_payload

    return {"kind": "unknown", "entity_count": 0}


def enrich_with_raw_values(
    report: Dict[str, Any], payload: Dict[str, Any], kind: str
) -> Dict[str, Any]:
    # Internal helper for merged stats only.
    if kind == "meks":
        catalog = parse_mek_catalog(payload)
        report["_raw_values"] = {
            "power": [float(spec.power) for spec in catalog.values()],
            "power_generation": [
                float(spec.power_generation) for spec in catalog.values()
            ],
            "ratio": [
                (float(spec.power_generation) / float(spec.power))
                for spec in catalog.values()
                if spec.power > 0
            ],
        }
    elif kind == "structures":
        catalog = parse_structure_catalog(payload)
        report["_raw_values"] = {
            "power": [float(spec.power) for spec in catalog.values()],
            "power_generation": [
                float(spec.power_generation) for spec in catalog.values()
            ],
            "ratio": [
                (float(spec.power_generation) / float(spec.power))
                for spec in catalog.values()
                if spec.power > 0
            ],
        }
    elif kind == "items":
        catalog = parse_item_catalog(payload)
        base_values: List[float] = []
        module_power_values: List[float] = []
        module_repeat_values: List[float] = []
        for spec in catalog.values():
            base_values.append(float(spec.base_power_usage))
            for module in spec.modules:
                module_power_values.append(float(module.power_on_use))
                module_repeat_values.append(
                    float(module.repeats if module.repeats is not None else 1)
                )
        report["_raw_values"] = {
            "base_power_usage": base_values,
            "module_power_on_use": module_power_values,
            "module_repeats": module_repeat_values,
        }
    else:
        report["_raw_values"] = {}
    return report


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
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    targets = resolve_json_targets(args.targets, recursive=args.recursive)
    if not targets:
        print("No JSON files matched target(s).", file=sys.stderr)
        return 1

    results: List[Dict[str, Any]] = []
    reports_for_merge: List[Dict[str, Any]] = []

    for file_path in targets:
        try:
            payload = load_json_file(file_path)
            filtered_payload = filter_entity_ids(payload, args.entity_glob)

            selected_kind = (
                args.kind if args.kind != "auto" else detect_entity_kind(file_path)
            )
            if selected_kind not in ("meks", "items", "structures"):
                print(
                    "Skipping %s: could not detect kind (--kind auto)." % file_path,
                    file=sys.stderr,
                )
                continue

            _, report = audit_one_file(file_path, selected_kind, args.entity_glob)
            report = enrich_with_raw_values(report, filtered_payload, selected_kind)
            reports_for_merge.append(report)
            results.append({"file": str(file_path), "report": report})
        except Exception as exc:  # pragma: no cover
            print("Error auditing %s: %s" % (file_path, exc), file=sys.stderr)

    if args.include_merged and reports_for_merge:
        if args.kind == "auto":
            # Auto mode can mix kinds; only merge if all are same kind.
            unique_kinds = {entry["report"]["kind"] for entry in results}
            if len(unique_kinds) == 1:
                merged = merge_audits(reports_for_merge, next(iter(unique_kinds)))
                results.append({"file": "<merged>", "report": merged})
            else:
                print(
                    "Merged summary skipped: auto mode produced mixed kinds.",
                    file=sys.stderr,
                )
        else:
            merged = merge_audits(reports_for_merge, args.kind)
            results.append({"file": "<merged>", "report": merged})

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
