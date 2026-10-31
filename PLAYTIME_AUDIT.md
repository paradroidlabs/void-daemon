# Campaign timing audit — October 29

The requested deliverable is a fleshed-out approximately twenty-minute campaign.
The eleven-mission .3 candidate now has continuous-input completion evidence at
19:30–20:54 active simulation across all four chassis, before narrative reading.
This supports the requested amount of playable prototype content. It does not
certify human enjoyment, device support, frame pacing or final balance.

## Full-route October 29.3 results

| Chassis | Completed missions | Active simulation | Failed missions |
|---|---:|---:|---:|
| Graviton | 11 | 1170.10 s / 19:30 | 0 |
| Bastion | 11 | 1198.48 s / 19:58 | 0 |
| Scrapper | 11 | 1187.55 s / 19:48 | 0 |
| Redline | 11 | 1253.52 s / 20:54 | 0 |

Mean: 1202.41 seconds / 20:02. These are complete new-campaign runs, not sums of
isolated encounter fixtures. All use seed RELAY-EXPEDITION, normal game actions,
first available mission rewards, an announced Watchdog approach, silent carrier
recovery and independent convoy channels. Three illustrated narrative interludes
are advanced immediately by the pilot; reading is not included in these totals.
No failed attempts, idle menus or arbitrary minimum-time waits fill the duration.

Preserved evidence: `artifacts/playtests/campaign-full-2026-10-29-3-<chassis>.json`.
Each includes eleven actual objective results/entry transitions, duration records,
the pilot hash, every source-script hash, and source_unchanged=true. Current source
was checked against those hashes with zero mismatches for all four runs. The
`--pilot-from` option is for explicit late-game fixtures; these full-route results
have an empty start_node and do not use that shortcut.

The exported EXE's embedded pack was also loaded directly with the installed
engine (`--main-pack <EXE>`). Its compiled .gdc resources completed all eleven
Graviton missions in the same 1170.10 active seconds, with zero failed missions.
That result fingerprints the compiled resources and is preserved as
`artifacts/playtests/campaign-packed-2026-10-29-3-graviton.json`. This verifies the
actual shipped content, distinct from claiming an interactive native EXE run.

New missions add physical matched-cell power routing, a damageable convoy whose
capacity inherits restored power and narrative choices, a three-stage shielded
Warden with six real remote conduits, and a continuous combat escape with gravity,
solid corridors, three jammers and a visible pursuing collapse front. Earlier
short probes below remain historical evidence, not the current content amount.

## Memory Spine expansion

The seventh mission adds nine sites, finite repair surveys, single-slot archive
deliveries, severable local reporting networks, real cover and a paused sector
map. First probe: 398.35 seconds for the sector / 612.65 seconds total. No hull
loss in that sector exposed travel-heavy pacing, so site spacing was tightened
rather than treating the extra transit time as a twenty-minute solution.

Compact geometry probe: 242.97 seconds for the sector / 457.27 seconds total.
The final candidate increases finite occluded vision to 720 units (the former
440 let an upgraded ship erase most guards before they saw it) and visibly
telegraphs pending scout uplinks. Final probe: 243.35 seconds for the sector /
457.65 seconds total, no failed missions. It still took no hull damage there;
stronger tactical pressure and varied encounters are explicitly unfinished.
Reading is advanced immediately by this pilot and is not added to the time.

Raw results: `artifacts/playtests/campaign-spine-wide-2026-10-29.json`,
`campaign-spine-compact-2026-10-29.json`, and
`campaign-spine-final-2026-10-29.json`. These intermediate probes share a build
label; do not identify their changing mission source by catalog hash alone.
The final EXE manifest fingerprints its actual source scripts.

## Actual continuous-input probe

`tests/campaign_pilot.gd` loads the campaign host, drives normal movement intents,
aims, charges/releases the real Graviton kit, uses legal chassis maneuvers, selects
offered rewards, and advances on actual objective events. It never writes ship
position, health, damage, invulnerability, enemy state or objective completion.
It knows objective locations and reads game state to steer/aim; it is not a model
of human perception, learning, reading or enjoyment.

Run with the installed engine:

    godot --headless --path . --fixed-fps 60 --log-file <absolute-log-path> --script res://tests/campaign_pilot.gd

The final generated JSON is `.godot/campaign-pilot-result.json`. Preserve a copy
before another run. `--fixed-fps 60` advances a normal 60 Hz simulation faster than
wall time; reported mission times are simulated active play, not elapsed wall time.
The pilot does not manufacture twenty minutes by waiting, holding a menu, retrying
indefinitely or slowing the engine. A failed probe is evidence, not a passed gate.

## Findings

| Mission | Initial probe, seconds | After picket redesign, seconds |
|---|---:|---:|
| Outer Link | 11.32 | 11.32 |
| Courier | 45.03 | 45.03 |
| Picket | 4.55 | 30.48 |
| Coolant Archive | 40.20 | 40.20 |
| Watchdog | 20.82 | 20.82 |
| Recovery | 66.45 | 66.45 |
| Total completed active simulation | 188.37 | 214.30 |

Both probes completed with Graviton and no failed missions. The second finished
the Watchdog at 23 hull and entered recovery after a bounded service repair. No
claim is made that the pilot chose human-like routes, aim, upgrades or priorities.
The initial probe is preserved at `artifacts/playtests/campaign-baseline-2026-10-29.json`.
The second is `artifacts/playtests/campaign-after-picket-2026-10-29.json`, with
catalog/pilot hashes, seed and build label. The initial probe predates those extra
metadata fields; do not imply it has a source hash it does not contain.

The picket's former clustered clear was trivialized by the intended gather/salvo
payoff. The redesign separates three guarded positions, allows their capture in
any order, requires uncontested low-speed securing, then extraction. Guard health
was not inflated. Its capture dwell totals 4.5 seconds; most additional time is
travel and engaging separated groups. This is a specific encounter improvement,
not a solution to the roughly sixteen-minute content gap.

## Runtime measurement

Checkpoint state now retains bounded attempt records: node ID, actual simulation
seconds, won/lost and whether the reward/progression was banked. Failed-attempt
time is separate from completed-mission time. The chapter ending lists recorded
completed mission durations. Reading, pauses and failed retries must not be
quietly reclassified as twenty minutes of authored campaign content. Legacy
version-2 checkpoints without attempt records load with an empty record list;
past per-node timings are not fabricated from their aggregate total.

## Still required

Human pacing, clarity and feel review of the new complete chapter; difficulty and
replayability tuning; actual phone/controller hardware checks and rendered FPS
measurement. Narrative remains newly authored prototype fiction rather than an
approved universe manuscript or finished graphic novel. Full A-Life ecology and
the separate music IDE are separate future projects, not delivered by this pass.
Artificial delays, repeated mandatory laps, HP-only inflation or forced deaths
are not acceptable substitutes. Repeat the probe after meaningful content changes
and retain failures/stalls. Then obtain real player/device observations, including
touch/controller handling and reading/pacing, before certifying the deliverable.

The older .1 EXE predates the distributed picket and timing ledger; .2 stops after
Memory Spine. Use the versioned .3 candidate for the full eleven-mission route.
