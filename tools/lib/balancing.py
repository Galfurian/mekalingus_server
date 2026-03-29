import fnmatch
import math
from typing import Any, MutableMapping, Optional
from .core import (
    CombatEntitySpec,
    ItemSpec,
    Slot,
    slot_weight_average,
    slot_factor_for_item,
)


def _apply_rounding(value: float, mode: str) -> float:
    if mode == "none":
        return value
    if mode == "int":
        return float(int(round(value)))
    if mode == "floor":
        return float(math.floor(value))
    if mode == "ceil":
        return float(math.ceil(value))
    raise ValueError("Unknown rounding mode: %s" % mode)


def _clamp_optional(
    value: float, min_value: Optional[float], max_value: Optional[float]
) -> float:
    if min_value is not None:
        value = max(value, min_value)
    if max_value is not None:
        value = min(value, max_value)
    return value


def as_json_number(value: float) -> Any:
    return int(value) if float(value).is_integer() else value


def _transform_value(
    old_value: float,
    scale: float,
    offset: float,
    min_value: Optional[float],
    max_value: Optional[float],
    rounding: str,
) -> float:
    updated = (old_value * scale) + offset
    updated = _clamp_optional(updated, min_value, max_value)
    return _apply_rounding(updated, rounding)


def rebalance_mek_or_structure_entity(
    entity: CombatEntitySpec,
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
    factors: dict[Slot, float],
    power_gen_ratio_blend: float = 1.0,
) -> dict[str, dict[str, Any]]:
    changes: dict[str, dict[str, Any]] = {}

    slot_multiplier = slot_weight_average(entity.slots, factors)

    old_power = float(entity.power)
    new_power = _transform_value(
        old_power,
        scale=(power_scale * slot_multiplier),
        offset=(power_offset * slot_multiplier),
        min_value=power_min,
        max_value=power_max,
        rounding=rounding,
    )
    if old_power != new_power:
        changes["power"] = {"old": old_power, "new": new_power}
        entity.power = as_json_number(new_power)

    old_power_generation = float(entity.power_generation)
    if power_gen_ratio is not None:
        safe_power = float(entity.power)
        current_ratio = (old_power_generation / safe_power) if safe_power > 0.0 else 0.0
        blended_ratio = (current_ratio * (1.0 - power_gen_ratio_blend)) + (
            power_gen_ratio * power_gen_ratio_blend
        )
        target_generation = safe_power * (blended_ratio * slot_multiplier)
        new_power_generation = _apply_rounding(
            _clamp_optional(target_generation, power_gen_min, power_gen_max),
            rounding,
        )
    else:
        new_power_generation = _transform_value(
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
        entity.power_generation = as_json_number(new_power_generation)

    return changes


def rebalance_item_entity(
    entity: ItemSpec,
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
    factors: dict[Slot, float],
    turn_budget: Optional[float] = None,
    module_budget_share: Optional[float] = None,
) -> dict[str, dict[str, Any]]:
    changes: dict[str, dict[str, Any]] = {}

    slot_multiplier = slot_factor_for_item(factors, entity.slot)

    old_base = float(entity.base_power_usage)
    new_base = _transform_value(
        old_base,
        scale=(base_power_scale * slot_multiplier),
        offset=(base_power_offset * slot_multiplier),
        min_value=base_power_min,
        max_value=base_power_max,
        rounding=rounding,
    )
    if old_base != new_base:
        changes["base_power_usage"] = {"old": old_base, "new": new_base}
        entity.base_power_usage = as_json_number(new_base)

    derived_module_max: Optional[float] = module_power_max
    if turn_budget is not None and module_budget_share is not None:
        budget_cap = (
            float(turn_budget) * float(module_budget_share) * slot_multiplier
        ) - float(new_base)
        budget_cap = max(0.0, budget_cap)
        if derived_module_max is None:
            derived_module_max = budget_cap
        else:
            derived_module_max = min(float(derived_module_max), budget_cap)

    modules = entity.modules
    for index, module in enumerate(modules):
        module_name = str(module.name)
        if not fnmatch.fnmatch(module_name, module_glob):
            continue

        old_module_power = float(module.power_on_use)
        new_module_power = _transform_value(
            old_module_power,
            scale=(module_power_scale * slot_multiplier),
            offset=(module_power_offset * slot_multiplier),
            min_value=module_power_min,
            max_value=derived_module_max,
            rounding=rounding,
        )
        if old_module_power != new_module_power:
            changes["modules.%d.power_on_use" % index] = {
                "module": module_name,
                "old": old_module_power,
                "new": new_module_power,
            }
            module.power_on_use = as_json_number(new_module_power)

    return changes
