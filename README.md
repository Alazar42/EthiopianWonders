# Ethiopian Wonders

An endless three-lane runner across a chain of small spherical planets, built for a **Tourism + AI** game jam. You run around real spheres (local gravity, no flat track), jump from planet to planet, and click glowing targets to discover Ethiopian wonders. Miss three and the run ends.

Godot **4.7**, Compatibility renderer, GDScript only. No plugins, no network, no API keys.

## Run it

1. Open the project folder in Godot 4.7 and press **F5** (main scene: `scenes/menus/main_menu.tscn`).
2. First open imports the assets; that takes a minute.

| Action | Input |
|---|---|
| Move one lane left / right | `A` / `D`, arrow keys, or gamepad D-pad / left stick |
| Discover a wonder | Left mouse click on the glowing target |
| Pause / resume | `Esc`, `P`, or gamepad Start |

The mouse never moves the camera or the runner; it only clicks targets and menus.

## How it plays

- The runner moves forward automatically along the surface of a planet. Gravity is `-normalize(P - C)`, the runner's up is always the local surface normal, and the three lanes bend with the sphere.
- The route is generated ahead of you from a seeded, weighted table of segments: straights, gentle curves, 60 degree turns, sharp 90 degree turns, landmark approaches, recovery stretches, and planet-to-planet hops. Segments behind you are freed.
- Each planet's route is a fixed amount of surface; then a glowing gate marks the launch and you fly to the next planet, which is visible ahead before you leave. In flight the runner's up vector blends between the two planets' outward directions (weighted by distance to each surface), so you stay feet-first toward whatever ground is nearest and land upright.
- A wonder appears beside the route with a floating target. The target's click window is measured in **route distance**: it opens shortly before you reach the landmark and closes just after you pass it. Click it inside the window to unlock the achievement and read a short fact. Let the window close and you lose a heart.
- Three hearts. Game over shows wonders found, distance and time, with Restart and Main Menu.

## Project layout

```
scenes/
  menus/main_menu.tscn         3D planet backdrop + Play / Quit
  game/game_world.tscn         the whole game wired together (start planet, route, player, camera, UI)
  game/game_over.tscn
  player/player.tscn           capsule runner (placeholder)
  planets/planet_*.tscn        four authored planets (terrain, atmosphere, grass, scenery)
  planets/planet_transition.tscn  launch / landing gate
  landmarks/landmark_target.tscn  clickable target (animations live in the scene)
  landmarks/landmark_<id>.tscn    one scenery scene per wonder
  ui/                          HUD, discovery popup, pause menu (default theme, no overrides)
scripts/
  managers/   game_manager (orchestration, tick), game_state (state machine), discovery_manager (hearts, stats)
  route/      route_generator, route_segment (sampled data + builders), route_frame, route_types
  player/     player_controller, lane_movement, player_gravity
  planets/    planet_controller, planetary_gravity (radial gravity math)
  landmarks/  landmark_data (resource), landmark_target
  camera/     gameplay_camera (smoothed follow frame + mouse picking ray)
  ui/         one small script per screen
data/landmarks/landmark_catalog.gd   curated wonders
tools/build_content.gd               generates planet meshes / scenes and graybox landmark scenes
tests/test_suite.gd                  headless gameplay tests
assets/                              meshes (generated), materials, shaders, Kenney models, wonder FBX models
```

There are intentionally **no path or runway meshes**. The planet is the track; the route is sampled data (`scripts/route`, which replaces the original spec's `scripts/paths`).

## Tests

```
godot --headless --path . --script res://tests/test_suite.gd
```

Exits with the number of failures. It covers: launch into the menu, spawning on the first planet, radial gravity, automatic running, lane changes and clamping, lane-frame stability over a long run, sharp-turn geometry, generation ahead and cleanup behind, planet flights (upright landing, never upside-down, planets and flight arcs keep clear of each other), clicking (active, empty space, repeat, late), missed targets and game over, popup content, restart, pause, real keyboard and mouse events, returning to the menu, and that every scene, script and resource loads with no missing references.

## Regenerating the planets

`tools/build_content.gd` writes `assets/meshes/*.res` and the `planet_*.tscn` / `landmark_*.tscn` scenes. The output is ordinary scene data; you can edit it by hand in the editor. To re-run it (needs a real renderer, so not `--headless`):

```
godot --path . --rendering-driver opengl3 --script res://tools/build_content.gd
```

This **overwrites** the generated scenes. Hand edits to those files are lost if you re-run it.

## Replacing placeholders

- **Runner:** open `scenes/player/player.tscn` and replace the `Body` and `Visor` meshes under `Visuals` with your model. Keep the root `Node3D` and the `Visuals` node. The root's origin is the middle of the capsule and the ground is `body_height` (0.9) below it, so position the model's feet there or change `body_height` in the Inspector.
- **Wonders:** each wonder is `scenes/landmarks/landmark_<id>.tscn`, referenced by `scene_path` in `data/landmarks/landmark_catalog.gd`. Swap the contents of that scene for the final model, or point `scene_path` somewhere else. Lalibela, Aksum and Gondar already use the supplied FBX models (with `assets/materials/artifact_*.tres` as material overrides); Simien, Danakil, Harar, Tiya and Bale are **graybox blockouts** made from primitives and Kenney pieces.
- **Add a wonder:** add an `_add(...)` line to the catalog and a scene at `landmark_<id>.tscn`.
- **Add a planet:** make a scene whose root is a `PlanetController` (set `radius`, `planet_name`) with a mesh of that radius, then add it to `Route > Planet Scenes` in `game_world.tscn`.
- **Tuning:** `Route` (lookahead, corridor clearance, window size, transition spacing), `Player` (speed, lane width, gravity) and `GameplayCamera` (distance, height, smoothing) all expose their values in the Inspector.

## Content and AI

All wonder text is local and curated in `data/landmarks/landmark_catalog.gd`; nothing is fetched at runtime. The facts are deliberately conservative but have **not been independently verified**; check them before publishing. A future AI knowledge provider can plug in through `LandmarkData.ai_insight_provider` (a `Callable` taking the landmark and returning a string). It is unset by default and nothing in the game depends on it.

## Known limitations

- No audio.
- Turn variety is gradual: the first planet has only straights and gentle curves, 60 degree turns arrive from the second planet, and sharp 90 degree turns from the third.
- The wonder FBX files reference texture files that are not in the project, so Godot logs missing-texture warnings on import. The scenes override the material, so nothing renders without a texture.
- Performance was measured at roughly 50 FPS average on an Intel HD 620 integrated GPU (Compatibility renderer); expect more on anything newer.
- `downloaded/` holds the original source archives and is ignored by Godot (`.gdignore`).
