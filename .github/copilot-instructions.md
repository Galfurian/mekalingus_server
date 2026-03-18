---
applyTo: '**'
---

# General Instructions

## GDScript Coding Guidelines

### Comments and Documentation
- Prefer writing comments on their own line rather than inline. 
- Regular comments should start with a space (`# `). 
- Documentation comments should start with a space (`## `).
- Region comments must strictly follow syntax without a space (`#region` / `#endregion`).

### General Formatting and Whitespace
- Use **Tabs** for indentation, **LF** for line breaks, and **UTF-8** encoding.
- Surround functions and class definitions with two blank lines. Use one blank line inside functions to separate logical sections.
- Keep individual lines under 100 characters (ideally under 80).
- Always use one space around operators and after commas. Do not use spaces to align expressions vertically.
- Use one space inside single-line dictionaries (e.g., `{ key = "value" }`).
- Use 2 indent levels for continuation lines to distinguish them from regular code blocks. 
  - *Exception:* Use 1 indent level for multiline arrays, dictionaries, and enums.
- Use a trailing comma on the last line of multiline arrays, dictionaries, and enums. Do not use trailing commas for single-line lists.
- Avoid combining multiple statements on a single line. The only exception is the ternary operator.
- Ternary operator format: `var result = value_if_true if condition else value_if_false`
- Wrap multiline conditional statements using parentheses rather than backslashes. 
- Avoid unnecessary parentheses in expressions and conditional statements unless needed for math order of operations or multiline wrapping.
- Place boolean operators (`and`, `or`) at the beginning of continuation lines, not the end.
- Use plain English boolean operators (`and`, `or`, `not`) instead of symbols (`&&`, `||`, `!`).
- Use double quotes (`"`) for strings by default, unless single quotes (`'`) allow you to escape fewer characters.
- Do not omit leading or trailing zeros in floats (e.g., `0.25`, `13.0`). 
- Use lowercase for letters in hexadecimal numbers (`0xfb8c0b`). 
- Use underscores in large numbers for readability (e.g., `1_000_000`).

### Naming Conventions
- `snake_case`: File names, functions, variables, and signals. (Name signals using past tense).
- `PascalCase`: Class names, node names, and enum names.
- `UPPER_SNAKE_CASE` (CONSTANT_CASE): Constants and enum members.
- Prepend a single underscore (`_`) for private variables, private methods, and virtual methods the user must override.

### Code Structure and Order
- Do not declare member variables if they are only used locally in a method; declare them as local variables instead.
- Declare local variables as close as possible to their first use.
- Organize class code from top to bottom in this specific order:
  1. `@tool`, `@icon`, `@static_unload`
  2. `class_name`
  3. `extends`
  4. Class doc comment (`##`)
  5. Signals
  6. Enums (declare each item on its own line)
  7. Constants
  8. Static variables
  9. `@export` variables
  10. Public variables, then private variables
  11. `@onready` variables
  12. `_static_init()` and other static methods
  13. `_init()`, `_enter_tree()`, `_ready()`, and main loop virtual methods (`_unhandled_input`, `_physics_process`)
  14. Public custom methods, then private custom methods

### Type Hinting
- Use static typing for variables (`var name: type`) and function returns (`func name() -> type:`).
- Use inferred typing (`:=`) when the type is written on the same line as the assignment and is visually unambiguous.
- Explicitly state the type if the assigned value's type is ambiguous (e.g., `var health: int = 0`, or when using `get_node()`).
- Use the `as` keyword to cast return types when appropriate (e.g., `get_node("LifeBar") as ProgressBar`).

## GIT Repository Management

### Commits

Use the Conventional Commits format: `<type>(scope): short summary`

Examples:

- `feature(config): support dynamic environment loading`
- `fix(core): handle missing config file gracefully`
- `test(utils): add unit tests for retry logic`

Allowed types (use these as `<type>` in your commit messages):

- `feature` – New features
- `fix` – Bug fixes
- `documentation` – Documentation changes only
- `style` – Code style, formatting, missing semi-colons, etc. (no code meaning changes)
- `refactor` – Code changes that neither fix a bug nor add a feature
- `performance` – Code changes that improve performance
- `test` – Adding or correcting tests
- `build` – Changes to build system or external dependencies
- `ci` – Changes to CI configuration files and scripts
- `chore` – Maintenance tasks (e.g., updating dependencies, minor tooling)
- `revert` – Reverting previous commits
- `security` – Security-related improvements or fixes
- `ux` – User experience or UI improvements

Other Notes:

- Prefer simple, linear Git history. Use rebase over merge where possible.
- Use `pre-commit` hooks to enforce formatting, linting, and checks before commits.
- If unsure about a change, open a draft PR with a summary and rationale.

### Release Guidelines

We follow a simplified Git-flow model for releases:

#### Branches

- `main`: Represents the latest stable, released version. Only hotfixes and release merges are committed directly to `main`.
- `develop`: Integration branch for ongoing development. All new features and bug fixes are merged into `develop`.
- `feature/<feature-name>`: Used for developing new features. Branch off `develop` and merge back into `develop` upon completion.

Here is the release process:

1. Prepare `develop` for Release:
    - Ensure all desired features and bug fixes are merged into `develop`.
    - Update `CHANGELOG.md` with changes for the new version, with the help of the command: `git log --pretty=format:"- (%h) %s" ...`
    - Update version numbers in relevant project files (e.g., `pyproject.toml`, `package.json`).
2. Make sure we start from a clean state:
    - Make sure you are on the `develop`, and that we start from there.
    - Perform final testing and bug fixing on this branch.
3. Merge to `main` and Tag:
    - Once the develop branch is stable, merge it into `main`:
      1. `git checkout main`
      2. `git merge --no-ff develop`  
    - Tag the release on `main`: `git tag -a v<version-number> -m "Release v<version-number>"`
    - Ask the user to push the changes to the `main` branch, including tags: `git push origin main --tags`
4. Merge back to `develop`:
    - Merge the main branch back into `develop` to ensure `develop` has all release changes:
      1. `git checkout develop`
      2. `git merge --no-ff main`
    - Ask the user to push the changes to `develop` branch: `git push origin develop`