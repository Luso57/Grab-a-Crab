# Repository Guidelines

## Project Structure & Module Organization

This is a Roblox experience built with Luau and Rojo. Application code lives in `src/`: `src/startup/` contains client/server entry points, `src/game/` holds shared game data and utilities, and `src/features/<feature>/` groups services, state slices, UI, hooks, modules, and classes by gameplay feature. Static images and audio belong in `assets/`. `default.project.json` maps source files into the Roblox DataModel. Dependencies are declared in `wally.toml`; treat `Packages/` and its `_Index/` contents as generated vendor code.

## Build, Test, and Development Commands

- `rokit install` installs the pinned tools from `rokit.toml`.
- `wally install` resolves dependencies into `Packages/` using `wally.lock`.
- `rojo serve default.project.json` starts live synchronization with Roblox Studio.
- `rojo build default.project.json -o RNG.rbxlx` creates a local place file.
- `selene src` lints project Luau against the Roblox standard library.

Run commands from the repository root. Do not hand-edit generated package files.

## Coding Style & Naming Conventions

Use tabs for Luau indentation and follow existing strict, typed Luau patterns. Name modules and React components in PascalCase (`SlimeEconomy.luau`, `InventoryRoot.luau`), hooks with a `use` prefix, and service modules with `ServiceClient` or `ServiceServer` suffixes. Reserve `.client.luau` and `.server.luau` for executable entry scripts. Keep feature-specific code inside its feature directory; shared domain code belongs in `src/game/`. Run Selene before submitting.

## Testing Guidelines

No first-party automated test framework or coverage threshold is currently configured. Validate changes in Roblox Studio through the Rojo session and exercise both client and server behavior. UI work can use `src/features/app/root.story.luau`; add adjacent `*.story.luau` files for reusable visual scenarios. Include clear manual test steps in the pull request.

## Commit & Pull Request Guidelines

Recent history uses short informal subjects; improve on this with concise, imperative messages such as `Add offline reward cap` or `Fix inventory selection state`. Keep each commit focused. Pull requests should explain behavior changes, list Studio test steps, link relevant issues, and include screenshots or recordings for UI/VFX changes. Call out edits to `default.project.json`, dependency manifests, or saved-data behavior explicitly.
