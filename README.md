# Ethiopian Wonders

An endless three-lane runner across a chain of small spherical planets, built for a **Tourism + AI** game jam. You run around real spheres (local gravity, no flat track), jump from planet to planet, and shoot glowing targets with your laser to discover Ethiopian wonders. Miss three and the run ends.

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
- You fly a small spaceship. A wonder appears beside the route with a floating target. The target's click window is measured in **route distance**: it opens shortly before you reach the landmark and closes just after you pass it. Shoot it inside the window (click, or press Space to lock on) to unlock the achievement and read a short fact. Let the window close and you lose a heart.
- Three hearts. Game over shows wonders found, distance and time, with Restart and Main Menu.

## The worlds

Five planets, each modelled on a real Ethiopian environment (reference photographs, not copied assets):

| World | Inspired by | What you see |
|---|---|---|
| Highland Farmland | the northern highlands | patchwork fields in gold, green and tilled earth, Meskel daisies, eucalyptus, tukul huts, flat-topped *ambas* |
| Rift Valley Lakes | the Rift Valley and Lake Tana | terracotta earth, turquoise lakes with sandy shores, flat-topped acacias, huts |
| Simien Escarpment | the Simien Mountains | tawny slopes, basalt columns, jagged crags, mist, giant lobelia |
| Danakil Salt and Fire | Dallol and Erta Ale | sulfur-yellow ground, white salt, glowing acid pools, black lava, volcanoes with glowing craters and steam |
| Bale Afro-alpine Moor | the Bale Mountains | silver cushion plants, giant lobelia and dead flower spikes, small cold lakes |

Each world drifts its own clouds and has its own mood: the sky light and fog blend to the next world's colours while you fly there.

The universe never runs out: a backdrop of 18 far-away planets (one ringed, some with moons) and drifting dust travels with the camera, so there is always more beyond the next world (`scenes/game/space_backdrop.tscn`).

## The wonders

Fifteen wonders appear as scenery beside the route, each with a clickable target. Three use your supplied FBX models; the rest are low-poly models built in the game's own style from photographs of the real places:

Lalibela, Aksum, Fasil Ghebbi (Gondar), Fasilides' Bath, Yeha, Debre Damo, Abuna Yemata Guh, Ura Kidane Mehret, Konso, Harar, Tiya, Simien, Bale, the Blue Nile Falls, and Erta Ale / Danakil.

## Project layout

```
scenes/
  menus/main_menu.tscn         3D planet backdrop + Play / Quit
  game/game_world.tscn         the whole game wired together (start planet, route, player, camera, UI)
  game/game_over.tscn
  game/space_backdrop.tscn     far-away planets and dust that follow the camera
  player/player.tscn           capsule runner (placeholder)
  planets/planet_*.tscn        five authored planets (terrain, atmosphere, grass, scenery, clouds)
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
  world/      space_backdrop (keeps the distant universe centred on the camera)
  ui/         one small script per screen
data/landmarks/landmark_catalog.gd   curated wonders
tools/build_content.gd               generates planets, scenery, landmark scenes and the space backdrop
tools/prop_meshes.gd, landmark_meshes.gd   the procedural low-poly models it uses
tests/test_suite.gd                  headless gameplay tests
assets/                              meshes (generated), materials, shaders, Kenney models, wonder FBX models
```

There are intentionally **no path or runway meshes**. The planet is the track; the route is sampled data (`scripts/route`, which replaces the original spec's `scripts/paths`).

## Tests

```
godot --headless --path . --script res://tests/test_suite.gd
```

Exits with the number of failures. It covers: launch into the menu, spawning on the first planet, radial gravity, automatic running, lane changes and clamping, lane-frame stability over a long run, sharp-turn geometry, generation ahead and cleanup behind, planet flights (upright landing, never upside-down, planets and flight arcs keep clear of each other), clicking (active, empty space, repeat, late), missed targets and game over, popup content, restart, pause, real keyboard and mouse events, returning to the menu, and that every scene, script and resource loads with no missing references.

## Regenerating the content

`tools/build_content.gd` writes `assets/meshes/*`, the `planet_*.tscn` and `landmark_*.tscn` scenes and `space_backdrop.tscn`. It colours the terrain (farmland, lakes, salt, glowing pools), places scenery so it never stands in water, and writes each object's own `clearance` so the route can clear mountains earlier than bushes. The output is ordinary scene data; you can edit it by hand in the editor. To re-run it (needs a real renderer, so not `--headless`):

```
godot --path . --rendering-driver opengl3 --script res://tools/build_content.gd
```

This **overwrites** the generated files; hand edits to them are lost if you re-run it. Colours, counts and moods per world live in the `BIOMES` table at the top of the script.

## Replacing placeholders

- **Ship:** `scenes/player/player.tscn`. Replace the `Ship` mesh under `Visuals` with your model (local -Z is forward), keep the `Cannons` markers where the lasers should leave, and set `body_height` (hover height above the ground) in the Inspector. The default ship is generated by `tools/prop_meshes.gd` (`spaceship`). Laser bolts and impact flashes are the scenes `laser_bolt.tscn` and `laser_impact.tscn`.
- **Wonders:** each wonder is `scenes/landmarks/landmark_<id>.tscn`, referenced by `scene_path` in `data/landmarks/landmark_catalog.gd`. Swap the contents of that scene for the final model, or point `scene_path` somewhere else. Lalibela, Aksum and Gondar use the supplied FBX models (with `assets/materials/artifact_*.tres` as material overrides); the other twelve are low-poly blockouts from `tools/landmark_meshes.gd`. They are stylised, not survey-accurate, so swap in final models when you have them.
- **Add a wonder:** add an `_add(...)` line to the catalog and a scene at `landmark_<id>.tscn`.
- **Add a planet:** add an entry to `BIOMES` in the tool and re-run it, or make a scene whose root is a `PlanetController` (set `radius`, `planet_name`, `ambient_color`, `fog_color`) with a mesh of that radius, then add it to `Route > Planet Scenes` in `game_world.tscn`. Give scenery nodes a `clearance` metadata value (their radius) so the route can clear them.
- **Tuning:** `Route` (lookahead, corridor clearance, window size, transition spacing), `Player` (speed, lane width, gravity) and `GameplayCamera` (distance, height, smoothing) all expose their values in the Inspector.

## Content and AI

All wonder text is local and curated in `data/landmarks/landmark_catalog.gd`; nothing is fetched at runtime. The facts are deliberately conservative but have **not been independently verified**; check them before publishing. A future AI knowledge provider can plug in through `LandmarkData.ai_insight_provider` (a `Callable` taking the landmark and returning a string). It is unset by default and nothing in the game depends on it.

## Known limitations

- No audio.
- Turn variety is gradual: the first planet has only straights and gentle curves, 60 degree turns arrive from the second planet, and sharp 90 degree turns from the third.
- Landmark text is curated from public sources (UNESCO and Wikipedia summaries) but not independently verified.
- The reference photographs used for inspiration came from Wikimedia Commons; none are shipped in the game.
- The wonder FBX files reference texture files that are not in the project, so Godot logs missing-texture warnings on import. The scenes override the material, so nothing renders without a texture.
- Performance was measured at roughly 50 FPS average on an Intel HD 620 integrated GPU (Compatibility renderer); expect more on anything newer.
- `downloaded/` holds the original source archives and is ignored by Godot (`.gdignore`).
