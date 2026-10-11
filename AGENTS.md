# Repository Guidelines


## Saved Player Data

Use [DataServiceTyped](https://github.com/leifstout/dataServiceTyped) for persistent player data. It saves server changes through ProfileStore and automatically replicates them to the client. The installed version is declared in `wally.toml`; use the project's shared wrapper in `src/game/Data.luau`, with the default data shape in `src/game/items/DataTemplate.luau`.

- Server: `local Data = require(ReplicatedStorage.Source.Game.Data).server`; read with `Data[player].inventory()`, set with `Data[player].inventory(newInventory)`, or update with `Data[player].inventory(function(old) return newInventory end)`.
- Client: require the same module's `.client`; read with `Data.inventory()` and listen with `Data.inventory.Changed(callback)`. Client writes only change the local mirror, so perform changes that must save on the server.
- If code can run before a profile loads, use `Data.Service:waitForData(player)` before accessing it. Keep saved values datastore-safe and update `DataTemplate.luau` when adding fields.
- See the [getting started guide](https://leifstout.github.io/dataServiceTyped/docs/intro/) and [service functions](https://leifstout.github.io/dataServiceTyped/docs/service-functions/) for the full API.

## Client-Server Remotes

Use [Networker](https://github.com/leifstout/networker) for client-server remote calls in this project. It is installed through `wally.toml`; require it with `require(ReplicatedStorage.Packages.Networker)`. Follow the existing feature service pattern instead of creating raw `RemoteEvent` or `RemoteFunction` instances.

- Server: `Networker.server.new("ServiceName", self, { self.action })` exposes only the listed methods. The handler receives the calling `player` first: `function Service:action(player: Player, value)`. Validate client-supplied arguments on the server.
- Client: `local networker = Networker.client.new("ServiceName", self)` uses the same service name; call an exposed method with `networker:fire("action", value)`.
- See `ShopServiceServer.luau` and `ShopServiceClient.luau` for a local example, and the [Networker README](https://github.com/leifstout/networker) for package usage.

## Rojo and Studio Workflow

This Roblox game uses Rojo for filesystem-to-Studio sync and has a Roblox Studio MCP connection for inspecting the live DataModel and playtesting when Studio is available. Keep script source in this repository's `src/`; use Studio MCP to verify the resulting instance tree and behavior.

- Before adding a Luau file, check `tools/genFeatureTree.js` and nearby files for its location and name. Put feature code in `src/features/<feature>/` (`classes/`, `modules/`, or `ui/` as appropriate), shared game code in `src/game/`, and executable startup scripts in `src/startup/`.
- The generator maps normal feature/client/shared modules under `ReplicatedStorage.Source` and filenames containing `Server` under `ServerScriptService` (with explicit exceptions in the generator). It capitalizes folder names in Studio, so `src/features/shop/ui/ShopRoot.luau` becomes `ReplicatedStorage.Source.Features.Shop.UI.ShopRoot`. Check the generator's special handling before using `init.luau` or an unusual filename.
- After adding, moving, or renaming Luau files, run `node tools/genFeatureTree.js` from the repo root to regenerate `default.project.json`; do not make mapping changes only in the generated JSON. Then sync with `rojo serve default.project.json` and check the new instance and its require path in Studio through MCP when connected. Use `rojo build default.project.json -o RNG.rbxlx` to verify the place can be built.

## Feature Architecture

Follow the feature-oriented service and class pattern already used by `PlotServiceServer`/`PlotServiceClient` and `classes/PlotServer`/`PlotClient` (also illustrated by [Easy Defense](https://github.com/leifstout/easy-defense/tree/main/src/features)).

- A `ServiceServer` or `ServiceClient` ModuleScript is a singleton manager for one feature. It owns startup, player or world event wiring, and the collection of live objects. Give it an `init` method and initialize it from the matching script in `src/startup/`, in dependency order. Add a client or server half only when the feature needs one.
- Put per-object state and behavior in `src/features/<feature>/classes/` with explicit `new` and `destroy` methods. Use separate `ThingServer` and `ThingClient` classes when both sides need their own representation; the service creates, tracks, and cleans up those instances.
- Put feature-specific data, configuration, and focused utilities in that feature's `modules/`; keep reusable game-wide data in `src/game/`. Keep feature UI in its `ui/` folder and initialize it from client code.
- Keep authoritative gameplay decisions, saved-data changes, and validation of client requests on the server. Let the client request an action through Networker; the server checks whether it is allowed and sends the resulting state or response.

## UI

Use [Vide](https://centau.github.io/vide/) for new reactive UI in this project; it is installed as `centau/vide@0.4.1` in `wally.toml`. Keep UI modules in the owning feature's `ui/` folder. Follow `src/features/shop/ui/ShopRoot.luau`, `ShopItemCard.luau`, and `ShopServiceClient.luau` for the local `Vide.create`, `source`, `derive`, `effect`, and `mount` patterns. Use Vide's own sources for ordinary UI state; add Charm only when shared state outside the UI needs it.
