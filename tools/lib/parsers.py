from dataclasses import asdict
from .core import (
    EffectSpec,
    ItemSpec,
    MekSpec,
    ModuleSpec,
    Slot,
    StructureSpec,
)
from typing import Any


def _parse_effect(raw: dict[str, Any]) -> EffectSpec:

    # Required fields.
    effect_class = raw["effect_class"]
    target = raw["target"]
    amount = raw["amount"]
    # Optional fields.
    damage_type = raw.get("damage_type", None)
    stat = raw.get("stat", None)
    duration = raw.get("duration", None)
    chance = raw.get("chance", None)
    radius = raw.get("radius", None)
    center_on_target = raw.get("center_on_target", None)

    return EffectSpec(
        effect_class=str(effect_class),
        target=str(target),
        amount=float(amount),
        damage_type=(str(damage_type) if damage_type is not None else None),
        stat=(str(stat) if stat is not None else None),
        duration=(float(duration) if duration is not None else None),
        chance=(float(chance) if chance is not None else None),
        radius=(float(radius) if radius is not None else None),
        center_on_target=(
            bool(center_on_target) if center_on_target is not None else None
        ),
    )


def _parse_module(raw: dict[str, Any]) -> ModuleSpec:

    # Required fields.
    name = raw["name"]
    passive = bool(raw["passive"])
    # Optional fields.
    power_on_use = float(raw.get("power_on_use", 0.0))
    module_range = float(raw.get("module_range", 0.0))
    cooldown = float(raw.get("cooldown", 0.0))
    repeats = int(raw.get("repeats", 0))
    effects = [_parse_effect(effect) for effect in raw.get("effects", [])]

    return ModuleSpec(
        name=str(name),
        passive=passive,
        power_on_use=power_on_use,
        module_range=module_range,
        cooldown=cooldown,
        repeats=repeats,
        effects=effects,
    )


def parse_item(raw: dict[str, Any]) -> ItemSpec:

    # Required fields.
    name = raw["name"]
    description = raw["description"]
    slot = raw["slot"]
    base_power_usage = raw["base_power_usage"]
    modules = [_parse_module(module) for module in raw["modules"]]

    return ItemSpec(
        name=str(name),
        description=str(description),
        slot=Slot(slot.strip().lower()),
        base_power_usage=float(base_power_usage),
        modules=modules,
    )


def parse_mek(raw: dict[str, Any]) -> MekSpec:

    # Required fields.
    name = raw["name"]
    description = raw["description"]
    appearance = raw["appearance"]
    size = raw["size"]
    health = raw["health"]
    armor = raw["armor"]
    shield = raw["shield"]
    power = raw["power"]
    sensor_range = raw["sensor_range"]
    slots = raw["slots"]
    icon = raw["icon"]
    speed = raw["speed"]

    # Optional fields with defaults.
    health_generation = raw.get("health_generation", 0)
    armor_generation = raw.get("armor_generation", 0)
    shield_generation = raw.get("shield_generation", 0)
    power_generation = raw.get("power_generation", 0)

    return MekSpec(
        name=str(name),
        description=str(description),
        appearance=str(appearance),
        size=str(size),
        health=int(health),
        health_generation=int(health_generation),
        armor=int(armor),
        armor_generation=int(armor_generation),
        shield=int(shield),
        shield_generation=int(shield_generation),
        power=int(power),
        power_generation=int(power_generation),
        sensor_range=int(sensor_range),
        slots=slots,
        icon=str(icon),
        speed=int(speed),
    )


def parse_structure(raw: dict[str, Any]) -> StructureSpec:

    # Required fields.
    name = raw["name"]
    description = raw["description"]
    appearance = raw["appearance"]
    size = raw["size"]
    health = raw["health"]
    armor = raw["armor"]
    shield = raw["shield"]
    power = raw["power"]
    sensor_range = raw["sensor_range"]
    slots = raw["slots"]
    icon = raw["icon"]
    structure_type = raw["structure_type"]
    structure_sub_type = raw["structure_sub_type"]
    passable = raw["passable"]

    # Optional fields with defaults.
    health_generation = raw.get("health_generation", 0)
    armor_generation = raw.get("armor_generation", 0)
    shield_generation = raw.get("shield_generation", 0)
    power_generation = raw.get("power_generation", 0)

    return StructureSpec(
        name=str(name),
        description=str(description),
        appearance=str(appearance),
        size=str(size),
        health=int(health),
        health_generation=int(health_generation),
        armor=int(armor),
        armor_generation=int(armor_generation),
        shield=int(shield),
        shield_generation=int(shield_generation),
        power=int(power),
        power_generation=int(power_generation),
        sensor_range=int(sensor_range),
        slots=slots,
        icon=str(icon),
        structure_type=str(structure_type),
        structure_sub_type=str(structure_sub_type),
        passable=bool(passable),
    )


def parse_item_catalog(payload: dict[str, Any]) -> dict[str, ItemSpec]:
    parsed: dict[str, ItemSpec] = {}
    for entity_id, raw in payload.items():
        parsed[entity_id] = parse_item(raw)
    return parsed


def parse_mek_catalog(payload: dict[str, Any]) -> dict[str, MekSpec]:
    parsed: dict[str, MekSpec] = {}
    for entity_id, raw in payload.items():
        parsed[entity_id] = parse_mek(raw)
    return parsed


def parse_structure_catalog(payload: dict[str, Any]) -> dict[str, StructureSpec]:
    parsed: dict[str, StructureSpec] = {}
    for entity_id, raw in payload.items():
        parsed[entity_id] = parse_structure(raw)
    return parsed


def catalog_to_json_dict(catalog: dict[str, Any]) -> dict[str, Any]:
    return {entity_id: asdict(spec) for entity_id, spec in catalog.items()}
