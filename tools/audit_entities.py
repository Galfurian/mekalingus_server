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


def _base_kind(kind: str) -> str:
    return kind.split(":", 1)[0]


def metric_explanations_for_kind(kind: str) -> Dict[str, Dict[str, str]]:
    base = _base_kind(kind)

    combat: Dict[str, Dict[str, str]] = {
        "health_generation_to_health_ratio": {
            "meaning": "Fraction of max health regenerated per turn.",
            "expected": "Typical stable range is ~0.00 to 0.03. Values near 0.10 are very high sustain.",
        },
        "armor_generation_to_armor_ratio": {
            "meaning": "Fraction of max armor regenerated per turn.",
            "expected": "Typical range is ~0.00 to 0.05. Values above ~0.08 can make armor too sticky.",
        },
        "shield_generation_to_shield_ratio": {
            "meaning": "Fraction of max shield regenerated per turn.",
            "expected": "Typical range is ~0.08 to 0.20. Lower values feel brittle; high values feel very resilient.",
        },
        "power_generation_to_power_ratio": {
            "meaning": "Fraction of max power restored each turn.",
            "expected": "Typical range is ~0.18 to 0.30 depending on role. Higher means faster ability cycling.",
        },
        "slot_weight": {
            "meaning": "Weighted average slot profile after applying slot factors.",
            "expected": "Around 1.0 is neutral. Above 1.0 indicates heavier slot load; below 1.0 lighter load.",
        },
        "power_per_slot_weight": {
            "meaning": "Power normalized by slot-weight profile to compare entities with different slot mixes.",
            "expected": "Should scale by class tier; compare medians inside each tier, then across tiers.",
        },
        "power_generation_per_slot_weight": {
            "meaning": "Power generation normalized by slot-weight profile.",
            "expected": "Should track power_per_slot_weight shape. Large divergence signals pacing imbalance.",
        },
        "spread_power_cv": {
            "meaning": "Coefficient of variation for power ($\\sigma / \\mu$).",
            "expected": "Higher means more archetype spread. Near 0 means flattening.",
        },
        "spread_power_generation_cv": {
            "meaning": "Coefficient of variation for power generation ($\\sigma / \\mu$).",
            "expected": "Should remain meaningfully above 0 to preserve class differentiation.",
        },
        "spread_power_ratio_cv": {
            "meaning": "Coefficient of variation for power_generation_to_power_ratio.",
            "expected": "Low-but-nonzero is normal. Near 0 indicates overly normalized regen behavior.",
        },
    }

    items: Dict[str, Dict[str, str]] = {
        "base_power_usage_per_slot_factor": {
            "meaning": "Base upkeep normalized by slot factor.",
            "expected": "Use for cross-slot comparison. Large-slot items can be higher in raw terms but similar normalized terms.",
        },
        "module_power_on_use_per_slot_factor": {
            "meaning": "Activation cost normalized by slot factor.",
            "expected": "Useful to compare burst cost parity across slot sizes.",
        },
        "module_effective_power": {
            "meaning": "Activation cost multiplied by repeats.",
            "expected": "Can be intentionally high for heavy repeat weapons. Evaluate alongside cooldown and role.",
        },
        "module_effective_power_per_slot_factor": {
            "meaning": "Repeated activation burden normalized by slot factor.",
            "expected": "High values are acceptable for mega items, but should align with tier fantasy and cooldown.",
        },
        "single_module_turn_cost_peak": {
            "meaning": "Worst-case one-turn draw: base_power_usage + most expensive module.",
            "expected": "Primary check for one-module-per-turn economy viability.",
        },
        "single_module_turn_cost_mean": {
            "meaning": "Average one-turn draw: base_power_usage + average module cost.",
            "expected": "Lower than peak; indicates typical rather than spike burden.",
        },
        "single_module_turn_cost_peak_per_slot_factor": {
            "meaning": "Peak one-turn draw normalized by slot factor.",
            "expected": "Best field for cross-slot outlier detection.",
        },
        "single_module_turn_cost_mean_per_slot_factor": {
            "meaning": "Mean one-turn draw normalized by slot factor.",
            "expected": "Useful for overall pacing fairness across slot classes.",
        },
        "over_budget_peak_count": {
            "meaning": "Count of items whose peak one-turn draw exceeds configured turn budget.",
            "expected": "Lower is safer. Nonzero can be intentional for high-risk high-reward items.",
        },
        "over_budget_mean_count": {
            "meaning": "Count of items whose mean one-turn draw exceeds configured turn budget.",
            "expected": "Usually very low. High values imply broad economy pressure.",
        },
    }

    if base == "items":
        return items
    if base in ("meks", "structures"):
        return combat
    return {}


def print_metric_explanations(results: List[Dict[str, Any]]) -> None:
    printed: set[str] = set()
    print("\nMetric explanations")
    print("  Derived fields only (non-obvious).")

    for entry in results:
        kind = str(entry.get("report", {}).get("kind", "unknown"))
        base = _base_kind(kind)
        if base in printed:
            continue

        explanations = metric_explanations_for_kind(kind)
        if not explanations:
            continue

        print("\n  Kind: %s" % base)
        for metric, details in explanations.items():
            print("  - %s" % metric)
            print("    meaning: %s" % details["meaning"])
            print("    expected: %s" % details["expected"])

        printed.add(base)


def audit_one_file(
    file_path: Path,
    kind: str,
    entity_glob: str,
    slot_factors: Dict[int, float],
    turn_budget: float | None,
    module_budget_share: float,
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
        return file_path, audit_items(
            filtered_payload,
            slot_factors,
            turn_budget=turn_budget,
            module_budget_share=module_budget_share,
        )

    raise ValueError("Unable to determine entity kind for %s" % file_path)


def print_human_report(results: List[Dict[str, Any]], include_merged: bool) -> None:
    for entry in results:
        print("\n%s" % entry["file"])
        print("  kind: %s" % entry["report"]["kind"])
        print("  entity_count: %d" % entry["report"]["entity_count"])
        for key, value in entry["report"].items():
            if key in ("kind", "entity_count", "_raw_values"):
                continue
            if key in (
                "turn_budget",
                "module_budget_share",
                "over_budget_peak_count",
                "over_budget_mean_count",
                "spread_power_cv",
                "spread_power_generation_cv",
                "spread_power_ratio_cv",
            ):
                print("  %s: %s" % (key, value))
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
    parser.add_argument(
        "--turn-budget",
        type=float,
        default=None,
        help=(
            "Optional per-turn power budget reference used for items. "
            "When set, item reports include over-budget counts."
        ),
    )
    parser.add_argument(
        "--module-budget-share",
        type=float,
        default=1.0,
        help=(
            "Share of turn budget available to a single activation. "
            "Example: 0.8 means base + one module should fit in 80%% of budget."
        ),
    )
    parser.add_argument(
        "--print-explanation",
        action="store_true",
        help="Print explanations for derived audit fields and expected value bands.",
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
                args.turn_budget,
                args.module_budget_share,
            )
            reports_for_merge.setdefault(selected_kind, []).append(report)
            results.append({"file": str(file_path), "report": report})
        except Exception as exc:  # pragma: no cover
            print("Error auditing %s: %s" % (file_path, exc), file=sys.stderr)

    if args.include_merged and reports_for_merge:
        for merge_kind, reports in reports_for_merge.items():
            merged = merge_audits(reports, merge_kind)
            results.append({"file": "<merged:%s>" % merge_kind, "report": merged})

    if args.print_explanation:
        print_metric_explanations(results)

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
