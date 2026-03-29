# AI Refactor TODO

This list is prioritized by urgency and ordered to avoid cross-invalidating changes.
Each completed TODO must be committed before moving to the next one.

## Urgency 1 - Critical Reliability

- [x] T1: Fix `target_distance_consideration` semantics to prefer closer targets.
  - File: `scripts/systems/ai/considerations/target_distance_consideration.gd`
  - Rationale: Current normalization rewards distance, which can skew attack targeting.
  - Dependency: None.

- [x] T2: Fix `retreat_direction_consideration` normalization.
  - File: `scripts/systems/ai/considerations/retreat_direction_consideration.gd`
  - Rationale: Dot-product divided by `1000.0` collapses differentiation of retreat tiles.
  - Dependency: None.

- [x] T3: Fix reachable tile filtering mutation during iteration.
  - File: `scripts/systems/ai/contexts/ait_turn_context.gd`
  - Rationale: Erasing while iterating can skip elements and create nondeterministic filtering.
  - Dependency: None.

## Urgency 2 - High Maintainability

- [x] T4: Cache intent evaluator instances in planner.
  - File: `scripts/systems/ai/ai_planner.gd`
  - Rationale: Avoid repeated evaluator allocation and make registry ownership explicit.
  - Dependency: None.

- [ ] T5: Extract shared intent helper utilities.
  - Files: `scripts/systems/ai/` (new helper + intent evaluator updates)
  - Rationale: Remove duplicated Manhattan distance and common helper logic across intents.
  - Dependency: Prefer after T1/T2 to avoid immediate follow-up churn.

## Urgency 3 - Safety and Polish

- [ ] T6: Harden AI profile validation with required-key checks per phase.
  - File: `scripts/systems/ai/ai_profile_manager.gd`
  - Rationale: Catch misconfigured considerations at profile load time instead of silently at runtime.
  - Dependency: None, but easier after phase behavior changes settle.

- [ ] T7: Rename typoed class `LocalForceSuperioritConsideration`.
  - File: `scripts/systems/ai/considerations/local_force_superiority_consideration.gd`
  - Rationale: Improve discoverability and consistency.
  - Dependency: Must be last or paired with a symbol-safe rename pass to avoid reference breakage.

## Execution Strategy

1. Complete all Urgency 1 items first (behavior correctness baseline).
2. Reassess TODO validity after each item; refine remaining TODO wording/scope if needed.
3. Complete Urgency 2 refactors after core behavior is stable.
4. Complete Urgency 3 hardening/polish at the end.
5. Commit after each completed TODO item.
6. Run diagnostics for touched files before every commit.
