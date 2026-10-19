# VOID//DAEMON roadmap — updated 2026-10-02

This replaces the original calendar estimates with playable outcome gates. Pricing and launch work remain downstream of a demo worth replaying. GAMEPLAY_REVIEW.md records the current feature contracts and risks.

## Current pass: implemented, awaiting human playtest

- Keep automatic DRIVER and ARC; add M1 hold/release precision charge.
- Add hold guard on M2/Space and Shift vent with directional boost.
- Add actual-damage DPS, source totals, bounded floating numbers, shield/hull hit feedback.
- Replace the Escape text dump with SHIP / WEAPONS / UPGRADES / STATS tabs: resource bars, module diagram, independent weapon cards, source damage shares, ranked upgrade cards and grouped effective stats. Fixed action footer; compact single-column layout and touch-sized tabs.
- Replace long enemy telegraphs with short local intent marks; shorten ARC visual persistence.
- Add four starter profiles and a ship/module schematic with charge/fork activity.
- Correct upgrade wording/implementation mismatches found in review.

## Short horizon: next 1–3 playtest iterations

Order matters; these are iteration groups, not promised elapsed weeks.

1. **Comprehension and control.** Play 60–120 seconds with each starter. Verify M1 charge/release, guard resource/break, and boost direction. Add a skippable 30-second tutorial, isolated weapon demos and upgrade preview animations. Split shield/hull bars; compact the schematic, add tooltips and a visibility toggle. Add dedicated mobile pause and release-safe precision control.
2. **Combat balance.** Measure per-source damage and specialist kill time. Tune precision heat, guard grace and boost cadence. Rebalance spawn density separately from enemy health/speed. Give specialists an isolated introduction and boss patterns distinct tells. Add danger direction cues and accessibility intensity settings.
3. **Build meaning.** Give each chassis a distinct silhouette and one clearly expressed starting specialization. Compare FORK / RETURN / ARC branches at the same pressure. Add effective before/after values to upgrade cards; remove options that do not change play. Profile dense-line targeting and peak feedback costs.

Exit: players can explain their build and damage source, make deliberate manual-action decisions, and voluntarily restart for another ship/build. Fix the observed confusion before widening scope.

## Medium horizon: coherent slice

- Two or three seed-assembled sectors with readable landmarks and explicit route rewards.
- One complete boss with clear phase changes and recovery opportunities; a second only after the first is strong.
- Central effective-stat calculation for UI, upgrades, weapons and replayable tests.
- Settings: rebinding, UI scale, diagram density, numbers, shake/tint, audio; controller and real Android-device QA.
- Seed descriptor/versioning; deterministic content assertions that do not promise replay equivalence.
- Run summary source breakdown, chosen build, death cause; reliable restart and checkpoint suspension.

Exit: complete runs support materially different spatial tactics with stable frame pacing and no unexplained damage/upgrade behavior.

## Long horizon: expand only from a proven core

- Additional ship kits, enemies and bosses with a purpose in the existing action economy.
- Manual compile recipes first; adaptive telemetry branches only if they solve a demonstrated need.
- Horizontal unlocks and optional challenge seeds; no baseline-power grind required to make movement feel good.
- More sector families and route interactions, save migration, device/export coverage and localization-friendly labels.
- Broader content production after a measured small slice proves retention through builds and combat, not hypothetical feature count.

## Deferred bets

1,000 enemies, cross-machine combat replays, procedural collision streaming, adaptive compile trees, elaborate boss protocol combinations and layered dynamic music remain optional later investments. Each needs its own evidence and performance budget.

## Verification used for this pass

Godot parse/import; integrated combat smoke; direct checks for automatic fire, automatic ARC damage, M1 charge/release, guard mitigation, boost/heat clearing, cooldown lockout and overkill clamping. Rendered HUD and Escape captures are stored in artifacts/. Physical mobile play and human engagement testing remain open.
