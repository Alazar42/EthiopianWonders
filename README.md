# Ethiopian Wonders — Spherical Endless Runner

An endless three-lane runner celebrating the cultural and natural wonders of Ethiopia across a chain of miniature 3D spherical worlds, inspired by *Super Mario Galaxy* planetary gravity and *Subway Surfers* lane navigation.

Developed for Godot 4.7+ (GL Compatibility / Forward+).

---

## 1. Overview & Mechanics

- **Pure Spherical Planet Traversal (No Floating Path Meshes)**: The runner moves directly along the spherical surface of large low-poly planets. Gravity points radially inward (`gravity = -up`). Head points outward into space and feet are firmly grounded on the planet surface.
- **Three-Lane Runner System**: Exactly three logical lanes: Left (-1), Center (0), Right (+1). Controls: `[A]` or `[Left Arrow]` to shift left, `[D]` or `[Right Arrow]` to shift right. Clamped to lane boundaries with smooth lateral interpolation.
- **Planetary Transitions (Never Inverted)**: When completing an expedition sector on a planet, the player launches across space on an elevated orbital trajectory to the destination planet. The player's up vector smoothly transitions from origin planet normal to destination planet normal, guaranteeing the runner lands upright with feet on the destination planet surface.
- **Tourism + AI Discovery Loop**: 
  - Clickable landmark targets (`target.glb` with pulsing reticle) approach as Ethiopian wonders are reached.
  - Left-clicking the target before the interaction deadline unlocks an achievement and displays a verified educational fact.
  - Three-Heart System: missing a landmark subtracts one heart. 3 missed discoveries ends the expedition (Game Over).
  - Offline curated catalog with an AI knowledge provider extension point.
- **Authored Low-Poly Visuals**:
  - Deep space galaxy skybox (`skybox_galaxy.png`).
  - Textured grassy and meadow sphere surfaces (`meadow_albedo.png`).
  - Authored low-poly environment props: trees, pines, grass patches, boulders, stones, fences, and launch bridges.
  - Real Ethiopian Wonder 3D models integrated into authored scenes:
    - **Rock-Hewn Churches of Lalibela** (`lalibela.fbx`)
    - **Obelisks of Aksum** (`axum.fbx`)
    - **Fasil Ghebbi of Gondar** (`fasiledes gondor.fbx`)
- **Unstyled, Clean UI**: Standard native Godot Control nodes for the Main Menu, Game HUD, Discovery Popup, Pause Menu, and Game Over Screen without intrusive custom theme overrides.

---

## 2. Controls

| Action | Key / Input |
|---|---|
| **Move Left** | `A` or `Left Arrow` |
| **Move Right** | `D` or `Right Arrow` |
| **Discover Wonder** | `Left Mouse Click` on in-world target |
| **Pause / Resume** | `Escape` or `P` |

---

## 3. Project Structure

```
res://
├── project.godot
├── README.md
├── scenes/
│   ├── menus/
│   │   └── main_menu.tscn               # Main menu with 3D rotating planetary backdrop
│   ├── game/
│   │   ├── game_world.tscn              # Primary game scene linking planets, player & UI
│   │   └── game_over.tscn               # Game over screen with run statistics
│   ├── player/
│   │   └── player.tscn                  # Capsule runner CharacterBody3D
│   ├── planets/
│   │   ├── spherical_planet.tscn        # Planet 1 (Lalibela Highlands with trees & grass)
│   │   ├── planet_axum.tscn             # Planet 2 (Aksum Antiquity with stele monument)
│   │   └── planet_gondar.tscn           # Planet 3 (Gondar Royal Enclosure)
│   ├── landmarks/
│   │   ├── landmark_target.tscn         # Clickable 3D target with Area3D collision
│   │   ├── landmark_lalibela.tscn       # Authored Lalibela wonder scene
│   │   ├── landmark_axum.tscn           # Authored Aksum wonder scene
│   │   └── landmark_gondar.tscn         # Authored Gondar wonder scene
│   └── ui/
│       ├── game_hud.tscn                # Standard HUD: Hearts, Wonders, Distance, Pause
│       ├── discovery_popup.tscn         # Educational wonder knowledge popup
│       └── pause_menu.tscn              # Standard pause menu
├── scripts/
│   ├── managers/
│   │   ├── game_manager.gd              # Orchestrates game loop & state transitions
│   │   ├── game_state.gd                # State definitions enum
│   │   └── discovery_manager.gd         # Hearts, discoveries, and stats tracker
│   ├── player/
│   │   ├── player_controller.gd         # Pure spherical runner & planetary transitions
│   │   ├── player_gravity.gd            # Planetary gravity math
│   │   └── lane_movement.gd             # 3-lane interpolation & banking
│   ├── planets/
│   │   ├── planet_controller.gd         # SphericalPlanet controller
│   │   └── planetary_gravity.gd         # Gravity & surface normal utilities
│   ├── landmarks/
│   │   ├── landmark_data.gd             # Landmark Resource & AI provider hook
│   │   └── landmark_target.gd           # Click picking, animations, and deadline logic
│   ├── camera/
│   │   └── gameplay_camera.gd           # Third-person planetary camera & raycasting
│   └── ui/
│       ├── main_menu.gd
│       ├── game_hud.gd
│       ├── discovery_popup.gd
│       ├── pause_menu.gd
│       └── game_over.gd
├── data/
│   └── landmarks/
│       └── landmark_catalog.gd          # Verified Ethiopian wonder catalog
├── assets/
│   ├── artifacts/                       # Lalibela, Aksum, Gondar FBX models
│   ├── textures/                        # Meadow, artifact, and galaxy skybox textures
│   └── kenney_mini-forest_1.0/          # 3D trees, grass, rocks, targets, bridges
└── tests/
    ├── test_suite.gd                    # Automated test suite (36 unit/integration tests)
    └── test_suite.tscn                  # Test runner scene
```

---

## 4. How to Run the Game

### In Godot Editor
Open the project directory in Godot 4.x and press **F5** (or run `res://scenes/menus/main_menu.tscn`).

### From Command Line
```bash
# Launch interactive game
godot

# Run directly into game world
godot scenes/game/game_world.tscn

# Run automated verification test suite
godot --headless tests/test_suite.tscn
```

---

## 5. Asset Replacement Workflow

- **Player Model**:
  Open `scenes/player/player.tscn`. The `Visuals/CapsuleMesh` can be replaced with any custom rigged character mesh or GLTF/FBX. The gameplay controller operates on the root `CharacterBody3D` and will adapt automatically.
- **Landmark Monuments**:
  Open `scenes/landmarks/landmark_lalibela.tscn`, `landmark_axum.tscn`, or `landmark_gondar.tscn`. Each scene encapsulates the 3D model and its `LandmarkTarget` instance. Replace the child model with new assets without altering game logic.
- **Target Mesh**:
  Open `scenes/landmarks/landmark_target.tscn`. Replace `Visuals/target` with any 3D marker or particle effect.
- **Educational Facts / AI Provider**:
  Curated facts reside in `data/landmarks/landmark_catalog.gd`. To connect an AI model or online service, set `LandmarkData.ai_insight_provider = callable`.
