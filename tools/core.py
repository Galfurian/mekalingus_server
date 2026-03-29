#!/usr/bin/env python3
"""Shared dataclasses and helpers for entity JSON tooling.

This module centralizes reusable logic used by audit/rebalance front scripts:
- JSON target discovery and IO.
- 1:1 dataclass parsing for meks, structures, and items.
- Slot-size normalization and slot-factor handling.
- Slot-aware audit metrics.
- Slot-aware rebalance transforms.
"""

from __future__ import annotations

import fnmatch
import glob
import json
import math
from dataclasses import asdict, dataclass, field
from pathlib import Path
from statistics import median
from typing import Any, Dict, Iterable, List, Mapping, MutableMapping, Optional, Sequence


# =============================================================================
# SLOT CONSTANTS / HELPERS
# =============================================================================


SLOT_SMALL = 0
SLOT_MEDIUM = 1
SLOT_LARGE = 2
SLOT_UTILITY = 3

SLOT_ORDER: List[int] = [SLOT_SMALL, SLOT_MEDIUM, SLOT_LARGE, SLOT_UTILITY]

SLOT_INDEX_TO_NAME: Dict[int, str] = {
    SLOT_SMALL: "small",
    SLOT_MEDIUM: "medium",
    SLOT_LARGE: "large",
    SLOT_UTILITY: "utility",
}

SLOT_NAME_TO_INDEX: Dict[str, int] = {
    name: index for index, name in SLOT_INDEX_TO_NAME.items()
}

DEFAULT_SLOT_FACTORS: Dict[int, float] = {
    SLOT_SMALL: 1.0,
    SLOT_MEDIUM: 1.0,
    SLOT_LARGE: 1.0,
    SLOT_UTILITY: 1.0,
}


def normalize_slot_name(slot: Any) -> str:
    text = str(slot).strip().lower()
    aliases = {
        "s": "small",
        "m": "medium",
        "l": "large",
        "u": "utility",
    }
    normalized = aliases.get(text, text)
    if normalized not in SLOT_NAME_TO_INDEX:
        raise ValueError("Unknown slot name: %r" % slot)
    return normalized


def parse_slot_token(token: Any) -> int:
    if isinstance(token, int):
        if token in SLOT_INDEX_TO_NAME:
            return token
        raise ValueError("Unknown slot index: %r" % token)

    text = str(token).strip().lower()
    if text.isdigit():
        return parse_slot_token(int(text))
    return SLOT_NAME_TO_INDEX[normalize_slot_name(text)]


def parse_slot_factor_map(raw: Optional[Any]) -> Dict[int, float]:
    factors = dict(DEFAULT_SLOT_FACTORS)
    if raw is None:
        return factors

    if isinstance(raw, Mapping):
        for key, value in raw.items():
            factors[parse_slot_token(key)] = float(value)
        return factors

    text = str(raw).strip()
    if not text:
        return factors

    for chunk in text.replace(";", ",").split(","):
        pair = chunk.strip()
        if not pair:
            continue
        if "=" in pair:
            left, right = pair.split("=", 1)
        elif ":" in pair:
            left, right = pair.split(":", 1)
        else:
            raise ValueError("Invalid slot factor expression: %r" % pair)
        factors[parse_slot_token(left)] = float(right.strip())

    return factors


def coerce_slot_vector(raw_slots: Sequence[Any], expected_len: int = 4) -> List[int]:
    slots = [int(value) for value in list(raw_slots)]
    if len(slots) < expected_len:
        slots.extend([0] * (expected_len - len(slots)))
    return slots[:expected_len]


def slot_weight_average(
    slots: Sequence[Any],
    slot_factors: Optional[Any] = None,
) -> float:
    factors = parse_slot_factor_map(slot_factors)
    vector = coerce_slot_vector(slots)

    total_slots = float(sum(vector))
    if total_slots <= 0.0:
        return 1.0

    weighted = 0.0
    for slot_index, count in enumerate(vector):
        weighted += float(count) * float(factors.get(slot_index, 1.0))

    return weighted / total_slots


def slot_factor_for_item(
    slot: Any,
    slot_factors: Optional[Any] = None,
) -> float:
    factors = parse_slot_factor_map(slot_factors)
    return float(factors.get(parse_slot_token(slot), 1.0))


# =============================================================================
# DATACLASSES (1:1 JSON MODELS)
# =============================================================================


@dataclass
class EffectSpec:
    effect_class: str
    target: str
    amount: float
    damage_type: Optional[str] = None
    stat: Optional[str] = None
    duration: Optional[float] = None
    chance: Optional[float] = None
    radius: Optional[float] = None
    center_on_target: Optional[bool] = None


@dataclass
class ModuleSpec:
    name: str
    passive: bool
    power_on_use: float
    module_range: float
    cooldown: float
    effects: List[EffectSpec] = field(default_factory=list)
    repeats: Optional[int] = None


@dataclass
class ItemSpec:
    name: str
    description: str
    slot: str
    base_power_usage: float
    modules: List[ModuleSpec] = field(default_factory=list)


@dataclass
class CombatEntitySpec:
    name: str
    description: str
    appearance: str
    size: str
    health: int
    health_generation: int
    armor: int
    armor_generation: int
    shield: int
    shield_generation: int
    power: int
    power_generation: int
    sensor_range: int
    slots: List[int]
    icon: str


@dataclass
class MekSpec(CombatEntitySpec):
    speed: int


@dataclass
class StructureSpec(CombatEntitySpec):
    structure_type: str
    structure_sub_type: str
    passable: bool


@dataclass
class NumericStats:
    count: int
    min_value: float
    max_value: float
    mean: float
    median: float


# =============================================================================
# IO / TARGET HELPERS
# =============================================================================


def resolve_json_targets(targets: Sequence[str], recursive: bool = True) -> List[Path]:
    resolved: Dict[str, Path] = {}

    for target in targets:
        target_path = Path(target)

        if target_path.is_file() and target_path.suffix.lower() == ".json":
            resolved[str(target_path.resolve())] = target_path.resolve()
            continue

        if target_path.is_dir():
            pattern = "**/*.json" if recursive else "*.json"
            for file_path in target_path.glob(pattern):
                if file_path.is_file():
                    resolved[str(file_path.resolve())] = file_path.resolve()
            continue

        for match in glob.glob(target, recursive=True):
            match_path = Path(match)
            if match_path.is_file() and match_path.suffix.lower() == ".json":
                resolved[str(match_path.resolve())] = match_path.resolve()

    return sorted(resolved.values())


def load_json_file(file_path: Path) -> Dict[str, Any]:
    with file_path.open("r", encoding="utf-8") as handle:
        data: Dict[str, Any] = json.load(handle)
    return data


def write_json_file(file_path: Path, data: Dict[str, Any]) -> None:
    with file_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, indent="\t", ensure_ascii=False)
        handle.write("\n")


def detect_entity_kind(file_path: Path) -> str:
    lower_path = str(file_path).lower().replace("\\", "/")
    if "/meks/" in lower_path:
        return "meks"
    if "/items/" in lower_path:
        return "items"
    if "/structures/" in lower_path:
        return "structures"
    return "unknown"


def filter_entity_ids(payload: Dict[str, Any], entity_glob: str) -> Dict[str, Any]:
    if entity_glob in ("", "*"):
        return dict(payload)

    filtered: Dict[str, Any] = {}
    for entity_id, entity_data in payload.items():
        if fnmatch.fnmatch(entity_id, entity_glob):
            filtered[entity_id] = entity_data
    return filtered


# =============================================================================
# NUMERIC HELPERS
# =============================================================================


def compute_numeric_stats(values: Iterable[float]) -> NumericStats:
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


def stats_to_dict(stats: NumericStats) -> Dict[str, float]:
    return {
        "count": stats.count,
        "min": round(stats.min_value, 3),
        "max": round(stats.max_value, 3),
        "mean": round(stats.mean, 3),
        "median": round(stats.median, 3),
    }


def apply_rounding(value: float, mode: str) -> float:
    if mode == "none":
        return value
    if mode == "int":
        return float(int(round(value)))
    if mode == "floor":
        return float(math.floor(value))
    if mode == "ceil":
        return float(math.ceil(value))
    raise ValueError("Unknown rounding mode: %s" % mode)


def clamp_optional(value: float, min_value: Optional[float], max_value: Optional[float]) -> float:
    if min_value is not None:
        value = max(value, min_value)
    if max_value is not None:
        value = min(value, max_value)
    return value


def transform_value(
    old_value: float,
    scale: float,
    offset: float,
    min_value: Optional[float],
    max_value: Optional[float],
    rounding: str,
) -> float:
    updated = (old_value * scale) + offset
    updated = clamp_optional(updated, min_value, max_value)
    return apply_rounding(updated, rounding)


def as_json_number(value: float) -> Any:
    return int(value) if float(value).is_integer() else value


# =============================================================================
# PARSING HELPERS
# =============================================================================


def _parse_effect(raw: Dict[str, Any]) -> EffectSpec:
    return EffectSpec(
        effect_class=str(raw["effect_class"]),
        target=str(raw["target"]),
        amount=float(raw["amount"]),
        damage_type=(str(raw["damage_type"]) if "damage_type" in raw else None),
        stat=(str(raw["stat"]) if "stat" in raw else None),
        duration=(float(raw["duration"]) if "duration" in raw else None),
        chance=(float(raw["chance"]) if "chance" in raw else None),
        radius=(float(raw["radius"]) if "radius" in raw else None),
        center_on_target=(bool(raw["center_on_target"]) if "center_on_target" in raw else None),
    )


def _parse_module(raw: Dict[str, Any]) -> ModuleSpec:
    effects = [_parse_effect(effect) for effect in raw.get("effects", [])]
    is_active = not bool(raw.get("passive", False))
    zero_range = float(raw.get("module_range", 0.0)) == 0.0

    if is_active and not raw.get("power_on_use", None):
        raise ValueError("Active module '%s' must have power_on_use." % raw.get("name", "<unknown>"))
    if zero_range and any(effect.target != "SELF" for effect in effects):
        raise ValueError("Module '%s' has zero range and non-self effects." % raw.get("name", "<unknown>"))

    return ModuleSpec(
        name=str(raw["name"]),
        passive=bool(raw.get("passive", False)),
        power_on_use=float(raw.get("power_on_use", 0.0)),
        module_range=float(raw.get("module_range", 0.0)),
        cooldown=float(raw.get("cooldown", 0.0)),
        effects=effects,
        repeats=(int(raw["repeats"]) if "repeats" in raw else None),
    )


def parse_item_catalog(payload: Dict[str, Any]) -> Dict[str, ItemSpec]:
    parsed: Dict[str, ItemSpec] = {}
    for entity_id, raw in payload.items():
        parsed[entity_id] = ItemSpec(
            name=str(raw["name"]),
            description=str(raw.get("description", "")),
            slot=normalize_slot_name(raw.get("slot", "utility")),
            base_power_usage=float(raw.get("base_power_usage", 0.0)),
            modules=[_parse_module(module) for module in raw.get("modules", [])],
        )
    return parsed


def parse_mek_catalog(payload: Dict[str, Any]) -> Dict[str, MekSpec]:
    parsed: Dict[str, MekSpec] = {}
    for entity_id, raw in payload.items():
        parsed[entity_id] = MekSpec(
            name=str(raw["name"]),
            description=str(raw.get("description", "")),
            appearance=str(raw.get("appearance", "")),
            size=str(raw.get("size", "")),
            health=int(raw.get("health", 0)),
            health_generation=int(raw.get("health_generation", 0)),
            armor=int(raw.get("armor", 0)),
            armor_generation=int(raw.get("armor_generation", 0)),
            shield=int(raw.get("shield", 0)),
            shield_generation=int(raw.get("shield_generation", 0)),
            power=int(raw.get("power", 0)),
            power_generation=int(raw.get("power_generation", 0)),
            sensor_range=int(raw.get("sensor_range", 0)),
            slots=coerce_slot_vector(raw.get("slots", [])),
            icon=str(raw.get("icon", "")),
            speed=int(raw.get("speed", 0)),
        )
    return parsed


def parse_structure_catalog(payload: Dict[str, Any]) -> Dict[str, StructureSpec]:
    parsed: Dict[str, StructureSpec] = {}
    for entity_id, raw in payload.items():
        parsed[entity_id] = StructureSpec(
            name=str(raw["name"]),
            description=str(raw.get("description", "")),
            appearance=str(raw.get("appearance", "")),
            size=str(raw.get("size", "")),
            health=int(raw.get("health", 0)),
            health_generation=int(raw.get("health_generation", 0)),
            armor=int(raw.get("armor", 0)),
            armor_generation=int(raw.get("armor_generation", 0)),
            shield=int(raw.get("shield", 0)),
            shield_generation=int(raw.get("shield_generation", 0)),
            power=int(raw.get("power", 0)),
            power_generation=int(raw.get("power_generation", 0)),
            sensor_range=int(raw.get("sensor_range", 0)),
            slots=coerce_slot_vector(raw.get("slots", [])),
            icon=str(raw.get("icon", "")),
            structure_type=str(raw.get("structure_type", "")),
            structure_sub_type=str(raw.get("structure_sub_type", "")),
            passable=bool(raw.get("passable", False)),
        )
    return parsed


def catalog_to_json_dict(catalog: Dict[str, Any]) -> Dict[str, Any]:
    return {entity_id: asdict(spec) for entity_id, spec in catalog.items()}


# =============================================================================
# AUDIT HELPERS (SLOT-AWARE)
# =============================================================================


def audit_combat_entities(
    payload: Dict[str, Any],
    selected_kind: str,
    slot_factors: Optional[Any] = None,
) -> Dict[str, Any]:
    if selected_kind == "meks":
        catalog = parse_mek_catalog(payload)
    elif selected_kind == "structures":
        catalog = parse_structure_catalog(payload)
    else:
        raise ValueError("Unsupported combat kind: %s" % selected_kind)

    raw: Dict[str, List[float]] = {
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

        slot_weight = slot_weight_average(spec.slots, slot_factors)
        raw["slot_weight"].append(slot_weight)
        safe_weight = slot_weight if slot_weight > 0.0 else 1.0
        raw["power_per_slot_weight"].append(float(spec.power) / safe_weight)
        raw["power_generation_per_slot_weight"].append(
            float(spec.power_generation) / safe_weight
        )

    report: Dict[str, Any] = {
        "kind": selected_kind,
        "entity_count": len(catalog),
        "_raw_values": raw,
    }
    for metric, values in raw.items():
        report[metric] = stats_to_dict(compute_numeric_stats(values))
    return report


def audit_items(
    payload: Dict[str, Any],
    slot_factors: Optional[Any] = None,
) -> Dict[str, Any]:
    catalog = parse_item_catalog(payload)

    raw: Dict[str, List[float]] = {
        "slot_factor_used": [],
        "base_power_usage": [],
        "base_power_usage_per_slot_factor": [],
        "module_power_on_use": [],
        "module_repeats": [],
        "module_effective_power": [],
        "module_power_on_use_per_slot_factor": [],
        "module_effective_power_per_slot_factor": [],
    }

    for spec in catalog.values():
        slot_factor = slot_factor_for_item(spec.slot, slot_factors)
        safe_factor = slot_factor if slot_factor > 0.0 else 1.0

        raw["slot_factor_used"].append(slot_factor)
        raw["base_power_usage"].append(float(spec.base_power_usage))
        raw["base_power_usage_per_slot_factor"].append(
            float(spec.base_power_usage) / safe_factor
        )

        for module in spec.modules:
            repeats = float(module.repeats if module.repeats is not None else 1)
            power_on_use = float(module.power_on_use)
            effective_power = power_on_use * repeats

            raw["module_power_on_use"].append(power_on_use)
            raw["module_repeats"].append(repeats)
            raw["module_effective_power"].append(effective_power)
            raw["module_power_on_use_per_slot_factor"].append(power_on_use / safe_factor)
            raw["module_effective_power_per_slot_factor"].append(
                effective_power / safe_factor
            )

    report: Dict[str, Any] = {
        "kind": "items",
        "entity_count": len(catalog),
        "_raw_values": raw,
    }
    for metric, values in raw.items():
        report[metric] = stats_to_dict(compute_numeric_stats(values))
    return report


def enrich_with_raw_values(
    report: Dict[str, Any],
    payload: Dict[str, Any],
    kind: str,
    slot_factors: Optional[Any] = None,
) -> Dict[str, Any]:
    # Keep this function as a public compatibility helper used by front scripts.
    if "_raw_values" in report:
        return report

    if kind in ("meks", "structures"):
        return audit_combat_entities(payload, kind, slot_factors)
    if kind == "items":
        return audit_items(payload, slot_factors)

    report["_raw_values"] = {}
    return report


def merge_audits(audits: List[Dict[str, Any]], kind: str) -> Dict[str, Any]:
    merged_raw: Dict[str, List[float]] = {}
    entity_count = 0

    for report in audits:
        entity_count += int(report.get("entity_count", 0))
        for metric, values in report.get("_raw_values", {}).items():
            if isinstance(values, list):
                merged_raw.setdefault(metric, []).extend(float(v) for v in values)

    merged: Dict[str, Any] = {
        "kind": "%s:merged" % kind,
        "entity_count": entity_count,
        "_raw_values": merged_raw,
    }
    for metric, values in merged_raw.items():
        merged[metric] = stats_to_dict(compute_numeric_stats(values))
    return merged


# =============================================================================
# REBALANCE HELPERS (SLOT-AWARE)
# =============================================================================


def rebalance_mek_or_structure_entity(
    entity: MutableMapping[str, Any],
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
    slot_factors: Optional[Any] = None,
) -> Dict[str, Dict[str, Any]]:
    changes: Dict[str, Dict[str, Any]] = {}

    slot_multiplier = slot_weight_average(entity.get("slots", []), slot_factors)

    old_power = float(entity.get("power", 0))
    new_power = transform_value(
        old_power,
        scale=(power_scale * slot_multiplier),
        offset=(power_offset * slot_multiplier),
        min_value=power_min,
        max_value=power_max,
        rounding=rounding,
    )
    if old_power != new_power:
        changes["power"] = {"old": old_power, "new": new_power}
        entity["power"] = as_json_number(new_power)

    old_power_generation = float(entity.get("power_generation", 0))
    if power_gen_ratio is not None:
        target_generation = float(entity.get("power", new_power)) * (
            power_gen_ratio * slot_multiplier
        )
        new_power_generation = apply_rounding(
            clamp_optional(target_generation, power_gen_min, power_gen_max),
            rounding,
        )
    else:
        new_power_generation = transform_value(
            old_power_generation,
            scale=(power_gen_scale * slot_multiplier),
            offset=(power_gen_offset * slot_multiplier),
            min_value=power_gen_min,
            max_value=power_gen_max,
            rounding=rounding,
        )

    if old_power_generation != new_power_generation:
        changes["power_generation"] = {
            "old": old_power_generation,
            "new": new_power_generation,
        }
        entity["power_generation"] = as_json_number(new_power_generation)

    return changes


def rebalance_item_entity(
    entity: MutableMapping[str, Any],
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
    slot_factors: Optional[Any] = None,
) -> Dict[str, Dict[str, Any]]:
    changes: Dict[str, Dict[str, Any]] = {}

    slot_multiplier = slot_factor_for_item(entity.get("slot", "utility"), slot_factors)

    old_base = float(entity.get("base_power_usage", 0))
    new_base = transform_value(
        old_base,
        scale=(base_power_scale * slot_multiplier),
        offset=(base_power_offset * slot_multiplier),
        min_value=base_power_min,
        max_value=base_power_max,
        rounding=rounding,
    )
    if old_base != new_base:
        changes["base_power_usage"] = {"old": old_base, "new": new_base}
        entity["base_power_usage"] = as_json_number(new_base)

    modules = entity.get("modules", [])
    for index, module in enumerate(modules):
        module_name = str(module.get("name", "module_%d" % index))
        if not fnmatch.fnmatch(module_name, module_glob):
            continue

        old_module_power = float(module.get("power_on_use", 0))
        new_module_power = transform_value(
            old_module_power,
            scale=(module_power_scale * slot_multiplier),
            offset=(module_power_offset * slot_multiplier),
            min_value=module_power_min,
            max_value=module_power_max,
            rounding=rounding,
        )
        if old_module_power != new_module_power:
            changes["modules.%d.power_on_use" % index] = {
                "module": module_name,
                "old": old_module_power,
                "new": new_module_power,
            }
            module["power_on_use"] = as_json_number(new_module_power)

    return changes
