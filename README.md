# Lumi: Bubblewood Chronicle — Godot 4.x Mobile Bubble Shooter

An original, premium 2D mobile Bubble Shooter game built with Godot 4.x (GDScript) in 720×1280 portrait mode. Featuring an offline-first architecture, deterministic hexagonal grid physics, procedural vector visuals, synthesized 16-bit PCM audio, 3 fantasy worlds, 30 handcrafted levels, and an expressive companion character named Lumi.

---

## 🌟 Key Features

### 1. Authoritative Hexagonal Grid & Physics Model
- **Grid Layout**: Offset hexagonal coordinate system (`BubbleGrid.gd`) with 8-column even rows and 7-column odd rows.
- **BFS Match Flood-Fill**: Breadth-First-Search cluster detection matching 3+ bubbles with wildcard and special support.
- **Multi-Source Ceiling Flood-Fill**: Detects and drops disconnected floating bubbles when anchor paths to row 0 are severed.
- **Deterministic Trajectory**: Raycast kinematics with multi-bounce lateral wall reflections and predictive ghost landing indicators.

### 2. Multi-World Progression & Star Gates (Phase 3)
- **3 Distinct Fantasy Worlds**:
  1. 🌲 **Whispering Woods (Levels 1–10)**: Serene emerald woodland introducing core mechanics, wall banking, and ceiling drop tactics.
  2. 💎 **Crystal Caverns (Levels 11–20)**: Glimmering subterranean grottos unlocked at **10 Stars**. Introduces **Bomb Bubbles (💣)**, **Lightning Beams (⚡)**, and **Frozen Ice Shells (🔒)**.
  3. 🌊 **Sunken Grove (Levels 21–30)**: Ancient mossy ruins unlocked at **25 Stars**. Introduces **Stone Boulders (🪨)**, **Rainbow Wildcards (🌈)**, and multi-obstacle layouts.
- **World Map (`scenes/menu/WorldMap.tscn`)**: Responsive visual map with Star Gate progress gauges, 30 interactive level nodes with 0–3 star ratings, and offline local persistence.

### 3. Special Bubbles & Obstacles
- 💣 **Bomb Bubble**: Detonates a 3×3 cluster (the target cell and all 6 surrounding neighbors), awards +50 points, triggers camera trauma, and drops severed branches.
- ⚡ **Lightning Bubble**: Emits an electric horizontal beam clearing the entire grid row (+60 points).
- 🌈 **Rainbow Bubble**: Universal wildcard adapting dynamically to form matches with adjacent color groups.
- 🪨 **Stone Bubble**: Indestructible granite obstacle immune to direct color matches; dropped via disconnection or destroyed with Bombs.
- 🔒 **Locked Ice Bubble**: Encased in ice; cracked into standard matchable bubbles when adjacent bubbles pop (+25 points).

### 4. Data-Driven Level Objectives
- **CLEAR_ALL (0)**: Pop all bubbles from the board.
- **CLEAR_COLOR (1)**: Clear a designated quota of target bubble colors.
- **REACH_SCORE (2)**: Achieve target score threshold before shot exhaustion.
- **CLEAR_SPECIAL (3)**: Clear or crack target count of special obstacles.

### 5. Companion Character: Lumi
- **Woodland Spirit Lumi**: Procedurally rendered companion with 6 interactive emotional reaction states (`IDLE`, `AIMING`, `MATCH_SUCCESS`, `LARGE_COMBO`, `WIN`, `LOSE`), directional eye tracking, and breathing animations.

### 6. Procedural Audio Synthesis
- **Zero-Dependency 16-bit PCM WAV Synthesizer (`AudioManager.gd`)**: Real-time programmatic generation of bubble pops, pitch-escalating combos, wall bounces, bomb detonations, lightning zaps, ice cracks, victory fanfares, and UI feedback clicks.

### 7. Version 3 Save System
- **Atomic File Persistence**: Writes via `.tmp` temporary files to eliminate corruptions.
- **Schema**: Version 3 with transparent automatic migration from V1/V2, star rating dictionaries, and seen tutorial flags.

---

## 📁 Project Structure

```
res://
├── project.godot
├── export_presets.cfg
├── ASSET_INVENTORY.md
├── scenes/
│   ├── main/
│   │   └── Main.tscn
│   ├── gameplay/
│   │   └── BubbleShooterGame.tscn
│   ├── bubble/
│   │   └── Bubble.tscn
│   ├── menu/
│   │   ├── MainMenu.tscn
│   │   ├── WorldMap.tscn
│   │   ├── SettingsMenu.tscn
│   │   └── TutorialOverlay.tscn
│   ├── visuals/
│   │   ├── ForestBackground.tscn
│   │   ├── ParticleManager.tscn
│   │   └── CompanionLumi.tscn
│   └── audio/
│       └── AudioManager.tscn
├── scripts/
│   ├── core/
│   │   ├── Constants.gd
│   │   ├── Enums.gd
│   │   └── Main.gd
│   ├── gameplay/
│   │   ├── BubbleShooterGame.gd
│   │   ├── Shooter.gd
│   │   └── AimGuide.gd
│   ├── bubble/
│   │   ├── Bubble.gd
│   │   ├── ColorGenerator.gd
│   │   └── SpecialBubbleHandler.gd
│   ├── grid/
│   │   ├── BubbleGrid.gd
│   │   ├── MatchDetector.gd
│   │   └── FloatingDetector.gd
│   ├── level/
│   │   ├── LevelData.gd
│   │   ├── LevelManager.gd
│   │   ├── ObjectiveManager.gd
│   │   └── WorldData.gd
│   ├── save/
│   │   └── SaveManager.gd
│   ├── audio/
│   │   └── AudioManager.gd
│   ├── visuals/
│   │   ├── ForestBackground.gd
│   │   ├── ParticleManager.gd
│   │   ├── ScreenFeedback.gd
│   │   ├── ScorePopup.gd
│   │   └── CompanionLumi.gd
│   └── ui/
│       ├── UIManager.gd
│       ├── MainMenu.gd
│       ├── WorldMap.gd
│       ├── SettingsMenu.gd
│       ├── TutorialOverlay.gd
│       └── DebugOverlay.gd
├── data/levels/
│   ├── level_1.json ... level_30.json
└── tests/
    ├── test_grid.gd
    ├── test_match.gd
    ├── test_floating.gd
    ├── test_score.gd
    ├── test_level.gd
    ├── test_save.gd
    ├── test_color_gen.gd
    ├── test_trajectory.gd
    ├── test_phase2_visuals.gd
    ├── test_phase3_features.gd
    ├── test_runner.gd
    ├── verify_bubble_core.py
    ├── verify_phase2_suite.py
    └── verify_phase3_suite.py
```

---

## 🧪 Automated Testing & Verification

Execute the complete automated test suite (528 assertions, 100% pass rate):

```bash
# Run all automated suites
python3 tests/verify_bubble_core.py
python3 tests/verify_phase2_suite.py
python3 tests/verify_phase3_suite.py
```

Or execute within a headless Godot instance:
```bash
godot --headless -s tests/test_runner.gd
```
