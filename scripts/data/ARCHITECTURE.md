# Data Layer Organization

## Core Rules

- Keep reusable combat behavior in `combat/` (`CombatActor`, calculators, shared systems).
- Keep concrete runtime entities in their own domain folders (`mek/`, `structure/`, `player/`).
- Keep templates beside their runtime domain (`mek_template.gd`, `structure_template.gd`, `player_template.gd`).
- Avoid reintroducing per-domain duplicate systems for damage, DOT, regen, cooldown, or passive modifiers.

## Generic Combat Flow

- `CombatActor` owns shared combat stats and state-reset/rebuild APIs.
- `CombatDamageCalculator` owns damage and DOT resolution.
- `ActiveEffectManager` and `CooldownManager` operate on generic combat actors.

## Concrete Actors

- `Mek` extends `CombatActor` and maps template stats/loadout into the shared combat pipeline.
- `Structure` extends `CombatActor` and uses `StructureTemplate` when available, with ad-hoc fallback data otherwise.

## Type-Hinting Policy

- Prefer explicit types for:
  - Actor/template properties.
  - Function inputs and return values.
  - Complex local variables.
- If a strict custom type introduces parser cycles in map runtime scripts, use a safe supertype (`MapEntity`, `Object`, `Dictionary`) and narrow locally.
