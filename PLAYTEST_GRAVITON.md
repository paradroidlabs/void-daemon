# Play the Graviton / Salvo kit

The offensive sequence is **hold to gather enemies and load the rack → release a charged missile salvo → ARC, piercing driver rounds, forks, and returns continue the attack**. Gravity belongs to the offensive hold. The separate phase skip is an escape.

Launch `play_combo_lab.cmd` for the example, already equipped with the supported ARC/driver upgrades. `play_combo_lab.cmd touch` shows the touch controls. `run_game.cmd` starts the normal five-minute run with the Graviton kit. `play_classic.cmd` retains the previous automatic-weapons/VENT mode.

## Controls

| Input | Action |
|---|---|
| WASD / arrows | Move |
| Mouse | Choose the formation in your aim cone |
| Hold M1 | Start the external graviton field and load up to six missiles |
| Release M1 | Launch the affordable payload in a staggered salvo |
| Shift or Space | Phase skip in your movement direction, or last movement direction when stationary |
| Esc / P | Pause |
| F1 / F2 / F3 | Select cluster / dispersed / boss encounter |
| F4 / F5 / F6 | Select salvo alone / graviton + salvo / full upgraded chain |
| R | Reset the current encounter |
| F7 / Report button | Open the complete visual scorecard; Restart returns to the same lab setup |
| T | Show or hide touch controls |

Controller: left stick moves, right stick aims, right trigger holds/releases the offensive sequence, right shoulder or A phase skips, Start pauses. Native lab selectors and report buttons support normal controller focus. Hardware controller and physical phone testing still need a hands-on pass; automated events and desktop touch preview do not establish device support.

Touch: hold and drag the right purple pad, then release to fire. Tap Phase Skip to escape. While holding the pad, slide into Phase Skip to cancel the charge and escape without an accidental launch. The left thumb remains on movement. Touch pause is the `II` button.

Shield is a passive regenerating resource. Phase Skip does not restore shield or dump reactor heat. M2/Q have no combat action in this kit.

## Quick comparison

1. Start with **Cluster + Full Chain**. The room waits until you begin the first hold, giving you time to read the controls and aim.
2. Hold M1 roughly a second. Watch the field gather the formation and the ship's rack cells light. Release to launch.
3. Watch the automatic weapons continue through the survivors. Open Report to compare actual source damage, hits, kills, and missile/field counters.
4. Reset with **Salvo Alone**, then **Graviton + Salvo**, to inspect the physical grouping difference. The automatic baseline processes remain present; Full Chain additionally equips fork, return, fanout, conductive, and pierce patches.
5. Try Dispersed and Boss. Decide when an early release, different angle, or reserved escape is more useful than a full charge.

The field does not apply a hidden combo damage multiplier. It changes enemy positions. Splash and chain reach use their ordinary spatial rules. Bosses resist displacement while still taking missile/automatic-weapon damage; the field can gather their adds.

## Current rules

- Six missiles load over approximately 0.8 seconds. Every committed salvo has a reload; tapping cannot bypass it.
- Gravity costs 8 heat at startup; each committed missile costs 4 heat, reserved once. Passive cooling is 22 heat/s in this kit. Unaffordable cells are shown separately in the HUD.
- The field affects at most twelve contacts and has a bounded lifetime. A small orbital core preserves visible silhouettes. Committed charger attacks resist the pull.
- Direct hits and splash cannot apply two full payloads to the same enemy. Missiles have limited steering, retargeting, and lifetime.
- Shift/Space share a 4.2-second cooldown and work at maximum heat. A phase skip cancels an uncommitted charge. A committed salvo can continue while you move or skip.
- Pausing, opening an upgrade/report, or losing focus clears active attack input and pending launches. Already spent heat stays spent.
- In the normal Graviton run, inactive VENT-specific cards are excluded. OVERCLOCK_KERNEL accurately describes its automatic-process effect.

## Verification and remaining judgement

The automated mechanics test compares the same formation with and without gravity, checks the six-cell rack, splash accounting, resource commitment, cancel/pause/focus behavior, phase aliases, touch slide cancellation, legal offers, and scorecard data. The integrated flow injects mouse input through the running scene and verifies actual missile damage followed by ARC damage.

`test_game.cmd` runs baseline smoke/report regressions, the mechanics check, the complete mouse-input flow, and actual two-thumb GUI-event routing including encounter/report controls. `tests/graviton_demo.gd`, run with a rendering Godot instance, saves charge, launch, follow-through, and scorecard images under `artifacts/graviton_*.png` using real simulation results.

`test_combo_stress.cmd` exercises 180 normal enemies plus the boss and verifies damage reconciliation and the one-field / twelve-contact / six-active-missile limits. Its raw engine timing samples include startup spikes; passing this check is not a stable-60-FPS or mobile-performance certification.

Automated correctness does not establish that this is fun. The next playtest should judge charge responsiveness, impact, whether partial salvos are useful, whether the same sequence becomes compulsory, and whether the automatic upgrades still change play. There is no claim of full replay determinism, validated mobile performance, or four completed chassis.

The pre-change project sources, tests, and launchers are preserved in `artifacts/baseline-before-graviton-20261016.zip`; the portable engine is shared from `.tools/godot` and is not duplicated in that archive.
