# Endless Relay — Game Design Document (GDD)

Version: 0.1
Author: Design Team
Date: 2025-11-18

## Executive Summary

Endless Relay is a single-player strategy runner where the core decision-making revolves around managing two complementary resources: stamina and momentum. The player controls a runner who is always moving forward across continent-scale routes made of stitched biomes and procedural segments. Gameplay emphasizes pace management, timing-based skill checks (perfect stride zones, perfect moves), and intermittent single-player run events that alter the rules temporarily.

The loop is simple to learn but deep to master: maintain forward motion, conserve and regain stamina, use momentum strategically, survive events, and progress the Distance Map to unlock new biomes, camps, and upgrades.

## Design Goals
- Accessible core loop: single-button/simple inputs but deep choices via resource management.
- Constant forward motion: keep forward momentum the baseline mechanic.
- Short, emergent decision windows: player choices should feel meaningful within seconds.
- Rhythm + skill hybrid: timing matters but no strict rhythm input is required.
- Strong feedback: clear audio/visual signals for stamina, momentum, perfects and events.

## Target Platforms
- Primary: Windows (desktop)
- Secondary: Linux, macOS, Consoles (TBD), Mobile (TBD)

Engine: Godot 4.x (prototype in GDScript; consider C# for performance-critical parts later).

## Core Loop (player-facing)
1. Run forward automatically.
2. Player controls pace (sustainable pace vs sprint), lane position, and three actions (jump, slide, vault).
3. Stamina drains with high pace and actions; regain via sustainable pace, perfect stride zones and clean moves.
4. Momentum accrues with smooth play; spend for short boosts or to bypass hazards.
5. Survive periodic Run Events.
6. Reach camps to rest and upgrade.

## Player Inputs and Controls
- Move Left / Right — lane switching (keyboard: A/D or Left/Right arrow; gamepad: stick/hat)
- Pace Increase / Decrease — influence speed (keyboard: W/S or hold Sprint key; gamepad: shoulder/button)
- Action Button — context-sensitive (tap = jump; hold + direction for slide/vault depending on lane/obstacle)
- Use Momentum — dedicated button to trigger active boosts
- Pause/Menu — Esc / Start

Accessibility notes: remappable inputs, colorblind palettes, font scaling, and simplified controls option.

## Core Mechanics — Systems Specification

High-level contract:
- Inputs: player pace setting, lateral movement, action triggers, boost use.
- Outputs: player forward velocity, stamina resource, momentum resource, collisions/events.
- Error modes: disconnected inputs or missing assets should fallback to safe defaults and log errors.

1) Movement
- Base always-forward speed: v_base (m/s). Player may multiply this by pace factor p ∈ [0.8, 1.6].
- Effective speed: v = v_base * p * terrain_speed_mod.
- Lane system: discrete lanes (3 by default). Lateral movement is instant or interpolated depending on tuning.

2) Stamina (S)
- Range: 0..S_max.
- Depletion rates (per second):
  - sustainable pace (p <= p_sustain): regen_rate = R_base.
  - above sustainable (p > p_sustain): drain_rate = D_base * (p - p_sustain).
  - actions: jump_cost, slide_cost, vault_cost (instant subtract).
  - terrain modifiers: uphill_multiplier > 1 increases drain; downhill can reduce drain or restore small amount.

Equations (example tunable defaults):
- S_max = 100.
- p_sustain = 1.0 (sustainable pace multiplier).
- D_base = 10 S/s at p=2.0 (linearly scaled), implemented as drain_rate = 5 * (p).
- R_base = +5 S/s when p <= 1.0 (and not performing actions).
- Action costs: jump_cost = 8, slide_cost = 6, vault_cost = 10.

Stamina Failure: when S <= 0 the runner becomes Exhausted for T_exhaust (e.g., 3s): cannot sprint, movement slowed by exhaustion_penalty and stamina regens slowly.

3) Momentum (M)
- Range: 0..M_max (M_max e.g., 100).
- Gain sources: continuous small gain for smooth movement without collisions (g_smooth), bonus gains for perfect-stride, clean landings, event survival streaks.
- Spend: boost_ability costs (Burst Run 40, Gravity Skip 30, Auto-Stride 25).
- Momentum is not required to keep running but provides strategic burst/utility.

Sample rules:
- g_smooth = +1 M/s when running at p between 0.95 and 1.15 and no recent collisions (>2s).
- Perfect stride: +15 M and +20 S.
- Clean jump landing (no speed loss): +8 M.

4) Perfect Stride Zones
- Short glowing strips on the ground (0.3–0.6s long). Hitting within the timing window grants stamina and momentum.
- Detection tolerance can be tuned (early/late leeway).

5) Terrain
- Terrain types: flat, uphill (gentle/steep), downhill, mud, rock.
- Each terrain has modifiers: speed_mod, stamina_drain_mult, momentum_gain_mod.
- Example: mud: speed_mod 0.85, stamina_drain_mult 1.3, momentum_gain_mod 0.8.

6) Obstacles & Actions
- Obstacles require correct action type (jump/slide/vault) and lane position.
- Successful action reduces stamina cost compared to failed action and may grant momentum on perfect timing.

7) Run Events
- Periodic large-scale events that override baseline rules. Examples:
  - Chase Event: spawn chaser; player must avoid being caught for T seconds. Chaser speed scales with player's speed.
  - Storm Event: lateral wind forces drift; players must compensate to stay in lane.
  - Avalanche Event: falling debris with safe lanes; requires quick lane changes and sprints.
  - Heatwave Event: stamina drains doubled except inside shade zones.

Events should be deterministic per seed for debugging and replay.

## Progression and Upgrades
- Distance Map composed of kilometers/segments. Every few km unlocks smaller milestones (camp, biome switch).
- Camps: rest points where player may trade collected resources for upgrades.
- Upgrade types:
  - Shoes: reduce stamina cost while sprinting (percent).
  - Water Pack: increases stamina regen and S_max.
  - Pacing Skills: passive bonuses (e.g., +perfect stride window, more momentum from perfects).

Currency: scrap / tokens collected along the route; scarcity tuned to pacing.

Save System: persistent save storing unlocks, upgrades, distance record, and lore collected.

## Biomes
- Examples: Grassland (intro), Desert (heat), Tundra (cold), Mountain (steep), Jungle (mud/slippery).
- Each biome has distinct palette, ambient music, common hazards, event frequency.

## UI / HUD
- Core HUD elements:
  - Stamina bar (color-coded), numeric optional
  - Momentum meter with charge markers for available boosts
  - Current pace indicator (sustain vs sprint)
  - Mini progress bar for next camp/biome
  - Event timer and status overlays
  - Notifications: Perfect Stride, Boost Ready, Exhausted

UX notes: Keep screen uncluttered; use layered notifications and transient modals for events.

## Audio Direction
- Dynamic layered music: tempo / layers change with pace and momentum.
- SFX: footfalls sync'd to pace, distinct sounds for perfects, boosts, exhaustion.
- Spatial audio for hazards and events.

## Visual Style & Art Direction
- Semi-stylized low-to-mid poly with clean silhouettes to keep read clarity at speed.
- Strong color languages per biome; high contrast for important gameplay elements (perfect zones, hazards).

## Monetization (optional)
- Preferred model: premium (one-time purchase) or demo + paid full game. Cosmetic DLC and additional route packs possible—no pay-to-win.

## Metrics & Success Criteria
- Retention metrics (day-1, day-7), average distance per session, upgrade conversion rate, average event survival rate, and progression funnel.

## Technical Notes
- Engine: Godot 4.x. Use GDScript for iteration, C# if profiling indicates need.
- Data driven: use JSON/Tres files for tuning parameters, terrain configs, event definitions.
- Object pooling for obstacles and VFX.

## Risk & Mitigations
- Risk: balancing stamina vs momentum can create unclear rules. Mitigation: telemetry and early playtests with tuning UI.
- Risk: procedural segments may feel repetitive. Mitigation: hand-authored anchor chunks + rulesets for variety.

## Acceptance Criteria
- A playable prototype demonstrates: always-forward movement, pace control with stamina cost, simple momentum resource, one perfect-stride mechanic, one run event, and a debug HUD.
- Full GDD should be included at `/docs/GDD.md` in the repo.

## Next Steps (implementation milestones)
1. Prototype: player movement, stamina, momentum, debug HUD.
2. Terrain & obstacles + perfect strides.
3. Events and route generator.
4. Camps, upgrades, and save system.

---
End of GDD v0.1
