from .core import (
    ItemSpec,
    Slot,
    NumericStats,
    CombatEntitySpec,
    slot_factor_for_item,
    slot_weight_average,
)
from statistics import median
import math
from typing import Any, Optional

# =============================================================================
# NUMERIC HELPERS
# =============================================================================


def compute_numeric_stats(values: list[float]) -> NumericStats:
    collected = list(values)
    if not collected:
        return NumericStats(count=0, min_value=0.0, max_value=0.0, mean=0.0, median=0.0)

    return NumericStats(
        count=len(collected),
        min_value=min(collected),
        max_value=max(collected),
        mean=(sum(collected) / float(len(collected))),
        median=float(median(collected)),
    )


def stats_to_dict(stats: NumericStats) -> dict[str, float]:
    return {
        "count": stats.count,
        "min": round(stats.min_value, 3),
        "max": round(stats.max_value, 3),
        "mean": round(stats.mean, 3),
        "median": round(stats.median, 3),
    }


def coefficient_of_variation(values: list[float]) -> float:
    collected = list(values)
    if not collected:
        return 0.0

    mean_value = sum(collected) / float(len(collected))
    if mean_value == 0.0:
        return 0.0

    variance = sum((value - mean_value) ** 2 for value in collected) / float(
        len(collected)
    )
    std_dev = math.sqrt(variance)
    return std_dev / abs(mean_value)

def apply_report_spread_metrics(report: dict[str, Any]) -> dict[str, Any]:
    raw = report.get("_raw_values", {})
    power_values = [float(v) for v in raw.get("power", [])]
    power_generation_values = [float(v) for v in raw.get("power_generation", [])]
    ratio_values = [float(v) for v in raw.get("power_generation_to_power_ratio", [])]

    report["spread_power_cv"] = round(coefficient_of_variation(power_values), 4)
    report["spread_power_generation_cv"] = round(
        coefficient_of_variation(power_generation_values),
        4,
    )
    report["spread_power_ratio_cv"] = round(
        coefficient_of_variation(ratio_values),
        4,
    )
    return report


# =============================================================================
# AUDIT HELPERS (SLOT-AWARE)
# =============================================================================


def audit_combat_entities(
    catalog: dict[str, CombatEntitySpec],
    selected_kind: str,
    factors: dict[Slot, float],
) -> dict[str, Any]:
    raw: dict[str, list[float]] = {
        "health": [],
        "health_generation": [],
        "health_generation_to_health_ratio": [],
        "armor": [],
        "armor_generation": [],
        "armor_generation_to_armor_ratio": [],
        "shield": [],
        "shield_generation": [],
        "shield_generation_to_shield_ratio": [],
        "power": [],
        "power_generation": [],
        "power_generation_to_power_ratio": [],
        "slot_weight": [],
        "power_per_slot_weight": [],
        "power_generation_per_slot_weight": [],
    }

    for spec in catalog.values():
        raw["health"].append(float(spec.health))
        raw["health_generation"].append(float(spec.health_generation))
        if spec.health > 0:
            raw["health_generation_to_health_ratio"].append(
                float(spec.health_generation) / float(spec.health)
            )

        raw["armor"].append(float(spec.armor))
        raw["armor_generation"].append(float(spec.armor_generation))
        if spec.armor > 0:
            raw["armor_generation_to_armor_ratio"].append(
                float(spec.armor_generation) / float(spec.armor)
            )

        raw["shield"].append(float(spec.shield))
        raw["shield_generation"].append(float(spec.shield_generation))
        if spec.shield > 0:
            raw["shield_generation_to_shield_ratio"].append(
                float(spec.shield_generation) / float(spec.shield)
            )

        raw["power"].append(float(spec.power))
        raw["power_generation"].append(float(spec.power_generation))
        if spec.power > 0:
            raw["power_generation_to_power_ratio"].append(
                float(spec.power_generation) / float(spec.power)
            )

        slot_weight = slot_weight_average(spec.slots, factors)
        raw["slot_weight"].append(slot_weight)
        safe_weight = slot_weight if slot_weight > 0.0 else 1.0
        raw["power_per_slot_weight"].append(float(spec.power) / safe_weight)
        raw["power_generation_per_slot_weight"].append(
            float(spec.power_generation) / safe_weight
        )

    report: dict[str, Any] = {
        "kind": selected_kind,
        "entity_count": len(catalog),
        "_raw_values": raw,
    }
    for metric, values in raw.items():
        report[metric] = stats_to_dict(compute_numeric_stats(values))
    return apply_report_spread_metrics(report)


def audit_items(
    catalog: dict[str, ItemSpec],
    factors: dict[Slot, float],
    turn_budget: Optional[float] = None,
    module_budget_share: float = 1.0,
) -> dict[str, Any]:
    raw: dict[str, list[float]] = {
        "slot_factor_used": [],
        "base_power_usage": [],
        "base_power_usage_per_slot_factor": [],
        "module_power_on_use": [],
        "module_repeats": [],
        "module_effective_power": [],
        "module_power_on_use_per_slot_factor": [],
        "module_effective_power_per_slot_factor": [],
        "single_module_turn_cost_peak": [],
        "single_module_turn_cost_mean": [],
        "single_module_turn_cost_peak_effective": [],
        "single_module_turn_cost_peak_per_slot_factor": [],
        "single_module_turn_cost_mean_per_slot_factor": [],
        "single_module_turn_cost_peak_effective_per_slot_factor": [],
    }

    over_budget_peak = 0
    over_budget_mean = 0
    over_budget_peak_effective = 0

    for spec in catalog.values():
        slot_factor = slot_factor_for_item(factors, spec.slot)
        safe_factor = slot_factor if slot_factor > 0.0 else 1.0

        raw["slot_factor_used"].append(slot_factor)
        raw["base_power_usage"].append(float(spec.base_power_usage))
        raw["base_power_usage_per_slot_factor"].append(
            float(spec.base_power_usage) / safe_factor
        )

        module_costs = [float(module.power_on_use) for module in spec.modules]
        module_effective_costs = [
            float(module.power_on_use)
            * float(module.repeats if module.repeats is not None else 1)
            for module in spec.modules
        ]
        peak_module_cost = max(module_costs) if module_costs else 0.0
        mean_module_cost = (
            (sum(module_costs) / float(len(module_costs))) if module_costs else 0.0
        )
        peak_module_effective_cost = (
            max(module_effective_costs) if module_effective_costs else 0.0
        )

        peak_turn_cost = float(spec.base_power_usage) + peak_module_cost
        mean_turn_cost = float(spec.base_power_usage) + mean_module_cost
        peak_turn_cost_effective = (
            float(spec.base_power_usage) + peak_module_effective_cost
        )
        raw["single_module_turn_cost_peak"].append(peak_turn_cost)
        raw["single_module_turn_cost_mean"].append(mean_turn_cost)
        raw["single_module_turn_cost_peak_effective"].append(peak_turn_cost_effective)
        raw["single_module_turn_cost_peak_per_slot_factor"].append(
            peak_turn_cost / safe_factor
        )
        raw["single_module_turn_cost_mean_per_slot_factor"].append(
            mean_turn_cost / safe_factor
        )
        raw["single_module_turn_cost_peak_effective_per_slot_factor"].append(
            peak_turn_cost_effective / safe_factor
        )

        if turn_budget is not None:
            budget = float(turn_budget) * module_budget_share * safe_factor
            if peak_turn_cost > budget:
                over_budget_peak += 1
            if mean_turn_cost > budget:
                over_budget_mean += 1
            if peak_turn_cost_effective > budget:
                over_budget_peak_effective += 1

        for module in spec.modules:
            repeats = float(module.repeats if module.repeats is not None else 1)
            power_on_use = float(module.power_on_use)
            effective_power = power_on_use * repeats

            raw["module_power_on_use"].append(power_on_use)
            raw["module_repeats"].append(repeats)
            raw["module_effective_power"].append(effective_power)
            raw["module_power_on_use_per_slot_factor"].append(
                power_on_use / safe_factor
            )
            raw["module_effective_power_per_slot_factor"].append(
                effective_power / safe_factor
            )

    report: dict[str, Any] = {
        "kind": "items",
        "entity_count": len(catalog),
        "_raw_values": raw,
    }
    for metric, values in raw.items():
        report[metric] = stats_to_dict(compute_numeric_stats(values))

    if turn_budget is not None:
        report["turn_budget"] = float(turn_budget)
        report["module_budget_share"] = float(module_budget_share)
        report["over_budget_peak_count"] = int(over_budget_peak)
        report["over_budget_mean_count"] = int(over_budget_mean)
        report["over_budget_peak_effective_count"] = int(over_budget_peak_effective)

    return report


def merge_audits(audits: list[dict[str, Any]], kind: str) -> dict[str, Any]:
    merged_raw: dict[str, list[float]] = {}
    entity_count = 0

    for report in audits:
        entity_count += int(report.get("entity_count", 0))
        for metric, values in report.get("_raw_values", {}).items():
            if isinstance(values, list):
                merged_raw.setdefault(metric, []).extend(float(v) for v in values)

    merged: dict[str, Any] = {
        "kind": "%s:merged" % kind,
        "entity_count": entity_count,
        "_raw_values": merged_raw,
    }
    for metric, values in merged_raw.items():
        merged[metric] = stats_to_dict(compute_numeric_stats(values))
    if kind in ("meks", "structures"):
        merged = apply_report_spread_metrics(merged)

    if kind == "items":
        if any("turn_budget" in report for report in audits):
            merged["turn_budget"] = next(
                float(report["turn_budget"])
                for report in audits
                if "turn_budget" in report
            )
        if any("module_budget_share" in report for report in audits):
            merged["module_budget_share"] = next(
                float(report["module_budget_share"])
                for report in audits
                if "module_budget_share" in report
            )

        merged["over_budget_peak_count"] = int(
            sum(int(report.get("over_budget_peak_count", 0)) for report in audits)
        )
        merged["over_budget_mean_count"] = int(
            sum(int(report.get("over_budget_mean_count", 0)) for report in audits)
        )
        merged["over_budget_peak_effective_count"] = int(
            sum(
                int(report.get("over_budget_peak_effective_count", 0))
                for report in audits
            )
        )

    return merged
