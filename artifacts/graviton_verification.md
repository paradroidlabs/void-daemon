# Graviton / Salvo prototype — technical handoff

Verified 2026-10-16 with the bundled Godot 4.7.1 Windows build.

The selected example is implemented as a single offensive sequence: M1 starts a graviton field and loads the rack; release launches the salvo into that formation; existing automatic processes continue through the survivors. Phase Skip is a separate escape and creates no gravity field.

## Evidence

| Requirement | Current evidence |
|---|---|
| Live gravity during the hold | `graviton_salvo.gd` owns the field; `graviton_combo_test.gd` compares the same moving formation with/without gravity |
| Charged salvo with useful partial payloads | Rack, resource reservation, repeated release rejection, and six physical missile launches are exercised by the mechanics test |
| Real spatial consequence | Mean pair separation: 127.56 units initially, 123.28 after ordinary movement, 47.28 with gravity under the same test interval |
| ARC after the salvo | `graviton_demo.gd` injects mouse input into the running scene and records a damage timeline; the observed ARC event follows a missile event |
| Existing fork/return continuation | The integrated flow requires positive actual damage from MASS_DRIVER, MASS_DRIVER_FORK, and MASS_DRIVER_RETURN as well as the salvo and ARC |
| Exact source totals | Existing damage/report regression passes; direct/splash de-duplication and repeated detonation rejection are covered by the new mechanics check |
| Separate reliable escape | Shared Shift/Space cooldown, maximum-heat availability, bounded endpoint, charge cancellation, and focused-picker input priority are checked |
| Touch is an implemented input path | Actual GUI-routed two-finger screen events move the ship, hold the attack, slide to cancel/phase, and release a full salvo |
| Lab is usable | Three encounter selectors, three loadouts, reset, report, and same-fixture restart are exercised; a listener verifies that the boss itself emits shots |
| Scorecard integration | Actual kit/source snapshot renders without scrolling; compact layouts expose a fifth Kit tab and retain Restart inside the viewport |
| Bounds under a swarm | Stress check with 180 normal enemies and a boss observes at most six active missiles, one field, and twelve affected contacts, with damage reconciliation |
| Baseline retained | `play_classic.cmd` runs classic mode; pre-change source/test/launcher archive is `baseline-before-graviton-20261016.zip` |
| Visible feedback | Rendered desktop and touch charge/salvo/follow-through/scorecard captures were inspected; rack cells, focal field, missile paths, control labels, and safe-area escape control are visible |

## Commands and results

- `test_game.cmd`: exit 0 for import, baseline smoke, baseline report, Graviton mechanics, integrated mouse flow, and native touch/fixture/report flow.
- `tests/graviton_input_test.gd` was rerun successfully after the final touch button sizing and input checks.
- `test_combo_stress.cmd` wraps the separately verified stress scenario.
- Rendered desktop and touch demo processes: exit 0, with actual source damage and `arc_after_salvo=true`.
- `git diff --check`: no whitespace errors.

One repeatable headless flow observed 12 pull contacts, 6 missiles, 7 kills, and 1294.52 actual damage. All five sources contributed. Rendered captures can run additional simulation ticks while waiting for readback, so their totals differ; this is not a combat replay determinism claim.

## Limits and next playtest

The stress check validates bounded behavior, not frame-rate certification. Raw engine timing samples include large startup spikes; neither stable 60 FPS nor mobile performance has been established. The known editor user-directory warning and hidden-window shader-cache warning did not prevent the verified runs.

Physical phone/controller testing and human judgement of charge feel, payoff, readability, and emergent choices remain open. The next useful action is to play `play_combo_lab.cmd`, beginning with Cluster + Full Chain, then compare the other encounters and loadouts. Additional chassis and a larger upgrade catalogue are outside this handoff.
