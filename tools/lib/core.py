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

from enum import StrEnum
import fnmatch
import glob
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import (
    Any,
    Optional,
)


# =============================================================================
# SLOT CONSTANTS / HELPERS
# =============================================================================


class Slot(StrEnum):
    SMALL = "small"
    MEDIUM = "medium"
    LARGE = "large"
    UTILITY = "utility"


DEFAULT_SLOT_FACTORS: dict[Slot, float] = {
    Slot.SMALL: 1.0,
    Slot.MEDIUM: 1.0,
    Slot.LARGE: 1.0,
    Slot.UTILITY: 1.0,
}


def slot_index_to_slot(slot_index: int) -> Slot:
    mapping = {
        0: Slot.SMALL,
        1: Slot.MEDIUM,
        2: Slot.LARGE,
        3: Slot.UTILITY,
    }
    return mapping.get(slot_index, Slot.UTILITY)


def slot_factor_for_item(
    factors: dict[Slot, float],
    slot: Any,
) -> float:
    if isinstance(slot, int):
        slot_enum = slot_index_to_slot(slot)
        return float(factors.get(slot_enum, 1.0))
    elif isinstance(slot, Slot):
        return float(factors.get(slot, 1.0))
    elif isinstance(slot, str):
        try:
            slot_enum = Slot(slot.strip().lower())
            return float(factors.get(slot_enum, 1.0))
        except ValueError:
            return 1.0
    else:
        return 1.0


def parse_slot_factor_map(raw: str) -> dict[Slot, float]:
    factors: dict[Slot, float] = DEFAULT_SLOT_FACTORS
    for chunk in raw.replace(";", ",").split(","):
        pair = chunk.strip()
        if not pair:
            continue
        if "=" in pair:
            left, right = pair.split("=", 1)
        elif ":" in pair:
            left, right = pair.split(":", 1)
        else:
            raise ValueError("Invalid slot factor expression: %r" % pair)
        factors[Slot(left.strip().lower())] = float(right.strip())
    return factors


def slot_weight_average(
    slots: list[int],
    factors: dict[Slot, float],
) -> float:
    total_slots = sum(slots)
    if total_slots <= 0.0:
        return 1.0
    weighted = 0.0
    for index, count in enumerate(slots):
        weighted += float(count) * float(slot_factor_for_item(factors, index))
    return weighted / total_slots


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
    repeats: Optional[int] = None
    effects: list[EffectSpec] = field(default_factory=list)


@dataclass
class ItemSpec:
    name: str
    description: str
    slot: Slot
    base_power_usage: float
    modules: list[ModuleSpec] = field(default_factory=list)


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
    slots: list[int]
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


def resolve_json_targets(targets: list[str], recursive: bool = True) -> list[Path]:
    resolved: dict[str, Path] = {}

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


def load_json_file(file_path: Path) -> dict[str, Any]:
    with file_path.open("r", encoding="utf-8") as handle:
        data: dict[str, Any] = json.load(handle)
    return data


def write_json_file(file_path: Path, data: dict[str, Any]) -> None:
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


def filter_entity_ids(payload: dict[str, Any], entity_glob: str) -> dict[str, Any]:
    if entity_glob in ("", "*"):
        return dict(payload)

    filtered: dict[str, Any] = {}
    for entity_id, entity_data in payload.items():
        if fnmatch.fnmatch(entity_id, entity_glob):
            filtered[entity_id] = entity_data
    return filtered
