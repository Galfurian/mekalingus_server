#!/usr/bin/env python3
"""Shared dataclasses and helpers for entity JSON tooling.

This module provides:
- 1:1 dataclass mappings for mek, structure, and item JSON payloads.
- File target resolution (single file, directory, glob, recursive glob).
- JSON load/save helpers with repository-friendly formatting.
- Generic stats helpers for numeric audits.
"""

from __future__ import annotations

import fnmatch
import glob
import json
import math
from dataclasses import asdict, dataclass, field
from pathlib import Path
from statistics import median
from typing import Any, Dict, Iterable, List, Optional, Sequence


# =============================================================================
# JSON 1:1 DATACLASS MODELS
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


# =============================================================================
# STATS MODELS
# =============================================================================


@dataclass
class NumericStats:
    count: int
    min_value: float
    max_value: float
    mean: float
    median: float


# =============================================================================
# FILE/TARGET HELPERS
# =============================================================================


def resolve_json_targets(targets: Sequence[str], recursive: bool = True) -> List[Path]:
    """Resolve a list of targets to concrete JSON file paths.

    Supported target styles:
    - Single file path.
    - Directory path (non-recursive *.json unless recursive=True).
    - Glob patterns (supports ** recursive glob).
    """
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
    """Write JSON with tabs to preserve repository style."""
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
# STATS HELPERS
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


def clamp_optional(
    value: float, min_value: Optional[float], max_value: Optional[float]
) -> float:
    if min_value is not None:
        value = max(value, min_value)
    if max_value is not None:
        value = min(value, max_value)
    return value


# =============================================================================
# PARSING / SERIALIZATION HELPERS
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
        center_on_target=(
            bool(raw["center_on_target"]) if "center_on_target" in raw else None
        ),
    )


def _parse_module(raw: Dict[str, Any]) -> ModuleSpec:
    effects = [_parse_effect(effect) for effect in raw.get("effects", [])]
    is_active = not bool(raw["passive"])
    zero_range = raw.get("module_range", 0) == 0
    
    if is_active and not raw.get("power_on_use", None):
        raise ValueError(f"Active module '{raw['name']}' must have power_on_use.")
    if zero_range and any(effect.target != "SELF" for effect in effects):
        raise ValueError(f"Module '{raw['name']}' has zero range and non-self effects.")
    
    return ModuleSpec(
        name=str(raw["name"]),
        passive=bool(raw["passive"]),
        power_on_use=float(raw.get("power_on_use", 0)),
        module_range=float(raw.get("module_range", 0)),
        cooldown=float(raw.get("cooldown", 0)),
        effects=effects,
        repeats=(int(raw["repeats"]) if "repeats" in raw else None),
    )


def parse_item_catalog(payload: Dict[str, Any]) -> Dict[str, ItemSpec]:
    parsed: Dict[str, ItemSpec] = {}
    for entity_id, raw in payload.items():
        modules = [_parse_module(module) for module in raw.get("modules", [])]
        parsed[entity_id] = ItemSpec(
            name=str(raw["name"]),
            description=str(raw["description"]),
            slot=str(raw["slot"]),
            base_power_usage=float(raw["base_power_usage"]),
            modules=modules,
        )
    return parsed


def parse_mek_catalog(payload: Dict[str, Any]) -> Dict[str, MekSpec]:
    parsed: Dict[str, MekSpec] = {}
    for entity_id, raw in payload.items():
        parsed[entity_id] = MekSpec(
            name=str(raw["name"]),
            description=str(raw["description"]),
            appearance=str(raw["appearance"]),
            size=str(raw["size"]),
            health=int(raw.get("health", 0)),
            health_generation=int(raw.get("health_generation", 0)),
            armor=int(raw.get("armor", 0)),
            armor_generation=int(raw.get("armor_generation", 0)),
            shield=int(raw.get("shield", 0)),
            shield_generation=int(raw.get("shield_generation", 0)),
            power=int(raw.get("power", 0)),
            power_generation=int(raw.get("power_generation", 0)),
            sensor_range=int(raw.get("sensor_range", 0)),
            icon=str(raw["icon"]),
            slots=[int(slot) for slot in raw["slots"]],
            speed=int(raw.get("speed", 0)),
        )
    return parsed


def parse_structure_catalog(payload: Dict[str, Any]) -> Dict[str, StructureSpec]:
    parsed: Dict[str, StructureSpec] = {}
    for entity_id, raw in payload.items():
        parsed[entity_id] = StructureSpec(
            name=str(raw["name"]),
            description=str(raw["description"]),
            appearance=str(raw["appearance"]),
            size=str(raw["size"]),
            health=int(raw.get("health", 0)),
            health_generation=int(raw.get("health_generation", 0)),
            armor=int(raw.get("armor", 0)),
            armor_generation=int(raw.get("armor_generation", 0)),
            shield=int(raw.get("shield", 0)),
            shield_generation=int(raw.get("shield_generation", 0)),
            power=int(raw.get("power", 0)),
            power_generation=int(raw.get("power_generation", 0)),
            sensor_range=int(raw.get("sensor_range", 0)),
            icon=str(raw["icon"]),
            slots=[int(slot) for slot in raw["slots"]],
            structure_type=str(raw.get("structure_type", "")),
            structure_sub_type=str(raw.get("structure_sub_type", "")),
            passable=bool(raw.get("passable", False)),
        )
    return parsed


def catalog_to_json_dict(catalog: Dict[str, Any]) -> Dict[str, Any]:
    """Serialize a dataclass catalog back to JSON-compatible dictionaries."""
    return {entity_id: asdict(spec) for entity_id, spec in catalog.items()}
