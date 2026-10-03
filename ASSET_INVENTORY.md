# BUBBLEWOOD — ASSET INVENTORY & PROVENANCE

This document details all visual, audio, and UI assets used in the **Bubblewood: Whispering Woods** project for Phase 2.

---

## 1. Provenance and Licensing
- **All graphics, shaders, and procedural render pipelines are 100% original, generated, and open-source under the MIT license.**
- **No external proprietary, paid, or copyrighted third-party game assets were used.**
- **Zero copyrighted characters, trademarks, textures, level layouts, or sound files from commercial bubble shooter games have been included.**

---

## 2. Visual Art Inventory

| Asset Name | Type | Description | Source / Technique |
| :--- | :--- | :--- | :--- |
| `Bubble (Red / Flame)` | Visual Node2D | Multi-layer glossy translucent sphere with Flame rune glyph | Procedural Godot Vector (`_draw()`) |
| `Bubble (Blue / Water)` | Visual Node2D | Multi-layer glossy translucent sphere with Water Drop rune glyph | Procedural Godot Vector (`_draw()`) |
| `Bubble (Green / Leaf)` | Visual Node2D | Multi-layer glossy translucent sphere with Leaf rune glyph | Procedural Godot Vector (`_draw()`) |
| `Bubble (Yellow / Sun)` | Visual Node2D | Multi-layer glossy translucent sphere with Sun rune glyph | Procedural Godot Vector (`_draw()`) |
| `Bubble (Purple / Moon)` | Visual Node2D | Multi-layer glossy translucent sphere with Crescent Moon rune glyph | Procedural Godot Vector (`_draw()`) |
| `Bubble (Cyan / Crystal)` | Visual Node2D | Multi-layer glossy translucent sphere with Diamond Crystal rune glyph | Procedural Godot Vector (`_draw()`) |
| `ForestBackground` | Node2D / Parallax | Multi-layered Whispering Woods backdrop, deep sky halo, floating fireflies, carved pillars | Procedural Vector + Sine Particle System |
| `Launcher / Shooter` | Node2D | Ancient carved wood pedestal with gold leaf flourishes and floating cyan power crystals | Procedural Vector + Spring Recoil |
| `CompanionLumi` | Node2D | Original magical fox companion with animated tail, ears, glowing crystal pendant, 6 reactive emotional states | Procedural Vector + State Machine |
| `ParticleManager` | CPUParticles2D Pool | Wall bounce sparks, pop crystal shards, large combo explosions, snap rings, victory golden fireworks | Dynamic `CPUParticles2D` pooling |
| `ScreenFeedback` | Node2D | Camera trauma shake system with quadratic decay & floating score popups | Dynamic Tween & Vector |
| `GameHUD & Modals` | Control / UI | Forest-themed parchment panels, 3-star reward meter, remaining shot indicator, pause modal | Godot Control Nodes + Flat StyleBoxes |

---

## 3. Audio Asset Inventory

| Sound Name | Type | Description | Source / Technique |
| :--- | :--- | :--- | :--- |
| `shoot` | AudioStreamWAV | Crisp resonant bubble launch pop tone | Procedural 16-bit PCM Sine Sweep Synthesizer |
| `bounce` | AudioStreamWAV | Bright crystal wooden wall bank ping | Procedural 16-bit PCM Damped Ping Synthesizer |
| `match` | AudioStreamWAV | Ascending harmonic chord chime (pitch scales with combo) | Procedural 16-bit PCM Harmonic Synthesizer |
| `drop` | AudioStreamWAV | Deep airy avalanche rush whoosh | Procedural 16-bit PCM Filtered Noise Synthesizer |
| `combo` | AudioStreamWAV | Ascending 4-note arpeggio fanfare | Procedural 16-bit PCM Arpeggio Synthesizer |
| `win` | AudioStreamWAV | Triumphant 3-chord victory jingle | Procedural 16-bit PCM Polyphonic Chord Synthesizer |
| `lose` | AudioStreamWAV | Gentle descending minor chord | Procedural 16-bit PCM Descending Minor Synthesizer |
| `ui_click` | AudioStreamWAV | Soft carved wooden button tap | Procedural 16-bit PCM Click Synthesizer |

---

## 4. Visual Quality & Accessibility Configuration
- **Accessibility Rune Glyphs**: Can be toggled on/off in the Pause Menu or programmatically via `SaveManager.show_accessibility_symbols`.
- **Reduced Effects Mode**: Disables camera shake, throttles particle allocations, and pauses background firefly simulations via `SaveManager.reduced_effects`.
