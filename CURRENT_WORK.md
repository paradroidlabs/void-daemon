# VOID//DAEMON — desktop experience checkpoint

## October 31 / source checkpoint

Branch: `checkpoint/first-arrival-2026-10-31`. Campaign source, tests, documentation,
preserved playtest evidence and original build checksums are included in this
checkpoint. See CHECKPOINT_2026-10-31.md. The existing .29.3 EXE/ZIP are unchanged
and remain local under builds; large binaries and unrelated captures are not Git
objects. This is a dedicated backup branch, not a merge to main/master or a new
public release. Older dated Git/publication statements below describe their
original build-time state.

## October 29.3 / First Arrival playable campaign

Eleven connected playable missions now include four substantial second-act
encounters: six-room matched-cell power routing, a damageable seven-checkpoint
convoy, three-phase Warden with six remote barrier conduits, and a continuous
combat escape with eleven gates, three jammers, solid corridors, gravity and a
visible pursuing collapse front. Existing seven missions remain intact. A third
illustrated three-page story hub adds a saved linked/independent transport choice
with actual hull/detail consequences. The chapter ends with an authored arrival,
not an abrupt test-arena result. Mission-entry retries and carried builds remain.

Four full normal-input campaigns finish without failed missions at 19:30 Graviton,
19:58 Bastion, 19:48 Scrapper and 20:54 Redline; mean 20:02, before reading. Raw
JSON records all eleven objective completions and source-script fingerprints.
This reaches the requested approximately twenty-minute content amount, not human
fun/device/FPS certification. See PLAYTIME_AUDIT.md and completion audit.

Expanded integration, tactical, failure and story tests pass. Old completed .1/.2
drafts migrate to the added unplayed act while retaining their build, rather than
opening an unearned new ending. Source .3 is frozen and packaged separately;
the .2 EXE below remains preserved. Sticky page/deploy/choice actions remain
visible outside the reading scroll at desktop and portrait sizes; native bounds
tests and rendered fixtures pass. This supersedes historical shorter-route status
below. No GitHub publication or shortcut change is claimed.

Standalone .3 campaign entry and embedded survival smoke both exit 0 without
runtime error lines. Loading this EXE's embedded pack through the installed
engine also completes all eleven Graviton missions in 1170.10 active seconds,
with compiled-resource fingerprints and no failures. Source duration probes
cover all four chassis. An optional
external-script full-route packaged probe did not initialize with usable output
and was stopped, so no full standalone playthrough is claimed. EXE SHA256:
`7e828a2a46d891d0fe6e61a75ad2b81b673d7d9ac9f345e367e2f85333001c5e`.
Use `builds/windows-desktop-2026.10.29.3/VOID-DAEMON.exe` / Play Expedition.cmd,
or its matching portable Windows x64 ZIP. Old desktop shortcuts remain unchanged.

## October 29 / active campaign goal — IN PROGRESS

Seventh pass adds Memory Spine after recovery: a seeded nine-site sector with
three severable relays, three one-use repair surveys, three single-slot cargo
deliveries, local gravity fields, real open-sided dock cover, bounded eight-live
activation, delayed interruptible scout reports and occluded finite perception.
M / pause MAP inspects the whole sector without obstructing combat. Desktop and
360x640 portrait map renders reviewed. Mission and checkpoint tests include the
actual campaign handoff, native map input/resume, capped repairs, delivery gating,
relay disconnection, wall-occluded scouting and final return. Fixed an audio
shutdown/redeploy race found in the rendered campaign fixture. Full regression
suite passes (headless audio teardown warnings remain; no runtime script errors).

The first wide-map pilot measured 10:13 total but revealed empty travel and no
sector hull loss. Tightened spacing and added physical cover instead of banking
that padding. Final candidate pilot: 457.65 seconds (7:38) total / 243.35 seconds
Memory Spine, Graviton, no failures, story reading excluded. Still no sector hull
damage: tactical pressure/all-chassis balance and the roughly twelve-minute
content gap remain open. Goal is NOT complete. See PLAYTIME_AUDIT.md. Candidate
.2 is packaged separately; .1 and all older artifacts remain preserved.

Playable local package: `builds/windows-desktop-2026.10.29.2/VOID-DAEMON.exe`
and matching Windows x64 ZIP. Build metadata fingerprints included source
scripts and records the dirty base commit; no GitHub publication is claimed.
Native packaged campaign entry and embedded survival smoke both exit 0 with
no runtime error lines. SHA256 executable:
`5d45b53513f12bbc806aacec2e451a6b89b9169688bfbc0fffec1918b74d525c`.
This packaging supersedes the older source-only .2 notes below. Existing desktop
shortcuts still target earlier builds; use this EXE / its Play Expedition.cmd.

Sixth pass adds two three-page visual terminal-fiction hubs (original prototype text, not imported/approved lore). Listening Room precedes Watchdog: spend 15 hull to spoof authorization and face four escorts, or repair up to 15 hull and face eight. Berth Room precedes recovery: broadcast for +50 carrier hull and up to three delivery interceptors, or remain silent with the original carrier hull/two-interceptor budget; both retain the six-alive cap. Pages can be revisited before committing; no forced reading timer. Page position, valid enumerated decisions and one-time resource changes persist in checkpoint flags. Retry does not replay choice costs. Scene-aware pilot/UI state avoids treating story pauses as player deaths.

Story tests cover deployment gating, page roundtrip, invalid/early/unaffordable choices, cost idempotency, actual escort counts and actual carrier/reinforcement changes. Rendered desktop and 360x640 layouts reviewed; campaign panel counters downscaling for readable controls. Original active-play timing remains separate from narrative reading; do not extrapolate a twenty-minute completion claim. Source version is bumped to next candidate desktop-2026.10.29.2, NOT yet exported. Packaged .1 remains unchanged. More material gameplay content and full pacing verification are still required.

Fifth pass adds a normal-intent continuous campaign pilot and persistent bounded attempt timing. Real objective completion, not forced kills/teleports, produced 188.37 seconds active simulation on the former six-node route. This disproves any twenty-minute claim. A redesign of the four-second clustered picket into three separated guarded capture positions plus extraction raised that node to 30.48 seconds; the second complete probe measured 214.30 seconds total, still far short. Guard HP was not raised. Raw probes and exact limitations are in PLAYTIME_AUDIT.md / artifacts/playtests. These are accelerated 60 Hz automated simulations, not human runtime/fun/device certification.

Attempt records separate won/lost/banked outcomes and persist with checkpoints; corrupt nonfinite/failed-banked records are rejected. The ending shows per-node completed mission times and failed-attempt time separately. New picket tests cover contention, low-speed securing, all positions and extraction; campaign integration covers the revised flow. The packaged October 29.1 EXE predates this pass and has NOT been silently overwritten. Further authored content and narrative/tactical depth must close the actual content gap; no artificial wait/retry duration substitution is acceptable.

Fourth pass adds `archive_recovery` after Watchdog: three damageable friendly carriers, low-speed automatic tethering, one-at-a-time towing, distance-based stranding, central service-cradle defense, finite delivery-triggered reinforcements (at most six alive), all/partial rescue outcomes and explicit cradle/all-carriers-lost failures. Actual enemy projectiles can damage friendly mission objects; player fire cannot. Saved `rescued_carriers` changes the chapter ending. The campaign integration now completes six missions through real objective events; recovery tests cover damage, tethering, continuous towing, caps, partial outcomes and failure reasons. Tests do not prove full human playtime.

Interim standalone candidate `desktop-2026.10.29.1` / file version 0.3.0.1 is built under `builds/windows-desktop-2026.10.29.1`. It contains the campaign work, unlike earlier EXEs. `Play Expedition.cmd` / `-- --campaign` launches the briefing; `-- --resume-campaign` resumes a checkpoint. Campaign native launch and embedded survival smoke exited 0. Full source regression suite passed; rendered recovery reviewed. Sandbox export initially failed reopening the temporary runtime; the approved unsandboxed build succeeded. Build metadata truthfully records the dirty tracked source state. No GitHub publication or desktop-icon change is claimed.

The twenty-minute objective is still active. No timed full human/bot input playthrough supports that duration yet; synthetic integration tests are not timing evidence. More authored encounter development, sustained substrate/session intelligence, stronger narrative presentation and balance/continuous-play verification remain. CAMPAIGN_PLAYTEST.md describes the interim route and gates.

Third campaign pass adds `coolant_archive` before Watchdog: a physically partitioned facility, two guarded coolant cores, recurring warned core discharges, an archive transfer requiring low-speed proximity, and return-to-entry extraction. Completion carries `archive_recovered` into campaign state. There are eight entities total (two cores, six guards), no wave spawner or artificial mission-duration wait. The mission's objective arrow uses a bounded doorway visibility graph with ship-sized clearance rather than directing the player into walls.

`CombatGeometry` provides optional solid-cover rules: enemy movement resolves against walls; projectiles/missiles use swept obstruction checks; ARC/driver targeting and manual kits cannot acquire/damage through cover; the Bastion beam visual clips to the first wall; missile splash is occluded. Empty geometry preserves legacy arenas. Facility tests cover accessible objectives, door routes, cover across weapon types, enemy wall bounds, transfer gating and extraction. Campaign integration drives the real facility chain and saves its result. Full source regression suite passes, with the known headless audio teardown warnings; rendered initial facility reviewed. Five missions are implemented, not a verified twenty-minute expedition. A full timed playthrough and new executable are still outstanding.

Second campaign pass adds a fourth node: a gravity-lane courier interception between relay and picket. Twelve ordered directional gates, actual StaticBody bulkheads and boundary walls, two gravity wells, a fixed-speed courier, collision damage and a 150-second failure limit are implemented. Automatic weapons are explicitly stowed during transit without deleting the build; existing steering/maneuvers remain. Finish before the courier to deny two real picket reinforcements; late completion still advances with that consequence. A world-space next-gate arrow and HUD progress avoid playing around another UI overlay. Camera no longer reserves invisible lab-toolbar space in campaign.

Checkpoint schema is version 2 and carries stable node IDs plus consequence flags. Resume resolves node ID rather than trusting a shifted array position; incompatible draft version-1 saves are rejected with an explanation and left untouched. Tests cover disk round-trip, index remapping and exact reinforcement counts. `tests/transit_test.gd` covers ordered/directional gates, teleport rejection, courier outcome, timeout, reference-path clearance, real CharacterBody/wall collision and gravity attachment. Rendered interception fixture is inspected; it is not human handling/playtime validation. The twenty-minute target remains unachieved; source-only changes are not in the existing EXE.

The active objective remains a fleshed-out roughly twenty-minute campaign. It is NOT complete. This pass adds a source-only three-mission foundation, not a twenty-minute claim: authored briefings/route status, relay extraction, a six-unit picket objective, an active Watchdog gate, reward selection with descriptions, capped service repairs, persistent chassis/patch/hull/totals, mission-entry retry and versioned ConfigFile checkpoint/resume. Existing packaged October 23 EXE does not contain these changes.

Entry: source hangar NEW EXPEDITION / RESUME CHECKPOINT. Campaign controls hide lab fixture switching and block debug boss skip. `tests/campaign_test.gd` drives actual mission objectives, checks reward idempotency and death retry, validates the state schema and round-trips a disk checkpoint. `tests/campaign_visual.gd` renders the hangar, first briefing and deployment/return. Placeholder narrative is newly authored prototype material, not imported/approved universe canon.

Still required toward the original objective: expand distinct mission content (physical facility geometry, traversal/pursuit and multi-objective encounters), richer linked narrative/visual presentation, full campaign debrief and pause/settings polish, retain meaningful substrate state across campaign nodes, tune encounter difficulty and progression for all chassis, measure a continuous approximately twenty-minute playthrough rather than imposing waits, verify checkpoint/controls across the larger route, and export/test a new standalone package. Do not mark the goal complete on three-node tests.

Updated October 23, 2026. Source state and delivery contract; not a claim of human-validated balance.

## October 23 substrate proof

Local candidate `desktop-2026.10.23.1` implements the first narrow substrate encounter. Hangar entry and lab F9/native selector start two scouts, an anchor, a flanker and an anchored destructible relay. Enemies act immediately. Finite occluded perception, delayed source-validated radio packets, report prevention/expiry, last-known positions, bounded decaying movement hypotheses, capped intercept prediction and the real locked charge warning are implemented. Destroy relay, then reach extraction for victory without fabricating a boss kill. R recreates session state; legacy fixtures retain their existing wait-for-attack behavior. There is no new wave spawning in this fixture.

The paused scorecard adds MIND: report/evidence counts and actual surviving unit tasks. The HUD stays outside the playfield. Source tests cover freed reporters, report path/range, stale knowledge, belief changes, fixed telegraph, extraction gating, pause/reset and legacy isolation; rendered fixtures cover hangar, arena and desktop/compact inspection. Full `test_game.ps1` now rejects runtime script errors even if Godot returns exit zero. Human perceived intelligence/fairness and phone/controller hardware remain unvalidated.

This supersedes the October 22 statement that all substrate systems are design-only. General ecology, resource logistics, richer coordinated planning, weapon recognition, full campaign/story, racer encounter and music IDE remain unimplemented. See PLAYTEST_SUBSTRATE.md. The new build is local/uncommitted, not a GitHub publication or desktop shortcut update; prior builds and unrelated untracked captures remain preserved.

## October 22 local candidate

`desktop-2026.10.22.1` adds non-destructive full live stats via Esc/P, controller Start and touch II. Lab Report/F7 inspects without ending. Resume preserves encounter/inertia; compact stats remain fixed tabs. Pause Options retains restart/hangar/quit and adds in-run sound/accessibility controls with bounded, scrollable operations on small displays (not a scrolling scorecard).

Local creator-authored music: drop Ogg Vorbis/MP3/PCM WAV into `assets/music` in source or `music` beside the EXE. Optional hangar/survival/lab/debrief context folders, shared fallback, two-voice crossfades, independent MUSIC slider, hive/pause ducking and native reload button. The user's actual files are pending their local copy; generated WAVs are test fixtures only.

`EXPEDITION_AND_MUSIC_DIRECTION.md` and `UNIVERSE_AND_SUBSTRATE.md` record the proposed session-born adaptive A-Life opposition, authored node/overworld, racing as an in-world encounter, sibling graphic-novel deliverable and separate connected chiptune composition/curation IDE. A time-trial fixture is only a handling test. None of those AI/world/story systems or the IDE are implemented by this patch. Existing narrative-workflow principles were memory-derived; no current Notion audit or manuscript import was performed.

Last published checkpoint remains October 19 (.3). October 22 work is a local, uncommitted candidate, with truthful dirty-source metadata; do not claim GitHub or existing desktop shortcuts were updated. Prior executables are preserved. The new EXE passed embedded smoke. Source regression suite passed including live stats and runtime raw-WAV music; rendered live stats/options reviewed at 1280x720, 640x360 and 360x640. Headless audio teardown/editor user-directory warnings remain a known harness caveat. An attempted external inspection script on the exported runtime did not complete and was stopped; do not represent that as release-level interactive inspection. Stress correctness passes with 180 normals plus boss, but measured a 751.75ms peak in this headless sample: no performance certification.

## Build identities

- Active four-kit implementation: canonical Documents checkout, branch prototype/graviton-salvo-checkpoint, local candidate desktop-2026.10.23.1. Published source base remains October 19 (.3).
- Separate Courier/Guard/Boost experiment: 4ade worktree, preserved on codex/courier-ui-checkpoint. A process command-line check proved the user's obstructing-panel screenshot was running that worktree. Do not conflate these control contracts.
- Master stays unchanged. Browser predecessors remain design lineage, not code continuity.

## Implemented and checked

- Graviton salvo retained; Bastion beam/Breach Step, Scrapper clamp/collapse/Tow Step, Redline close plasma/position-only Backtrace implemented with explicit flight and resource profiles.
- Inertial coast/counter-thrust, independent aim, bounded softened gravity, actual heading/travel/force telemetry, Orbit F8 fixture, flight statistics on the scorecard.
- Boot hangar, ship selection and previews, survival/lab, return/restart, persistent sound/sensory settings.
- Gameplay-only hive observations, live tactical PiP, terminal subtitles and optional installed system voice; no personal data/network/model access.
- First procedural audio pass: bounded transient voices, dedicated continuous kit/thrust/void roles, ducking, volume controls and limiter.
- Upright boss health bar and original user's boss-clear screenshot already published at 9cbea49.
- Passive HUD no longer overlays the arena. Combat uses a clipped viewport between status rail and lower dock. Module details remain in Courier pause inspection.
- Wider default 82% camera, bounded 65–125%, mouse wheel / +/- / dock controls. Aim and spawn geometry account for the actual view.
- Source suites and rendered fixtures cover four kits, heat/cancel, target caps, decoy cleanup, rewind invariants, exact damage and final boss hit, scorecard, UI non-overlap/zoom/aim, native two-thumb event routing, waveform headroom and sound role bounds.
- Rendered standalone .2 candidate: actual mouse selection, Bastion lab entry and hold/release, pause, hangar return verified. User took control; preserve that process. .3 has a separate path and persistent title/footer identification.
- Rendered UI fixtures reviewed on this AMD Radeon desktop. Three installed English system voices available. 180 normals + boss stress passes bounded checks, not FPS certification.

## Delivery contract

Run test_game.cmd and test_combo_stress.cmd. For local candidates, export to a new versioned path and keep build.json's dirty-source flag truthful. For a requested publication, commit/push the scoped source, export from a clean tracked worktree, inspect generated build.json (commit, clean flag, SHA256), run embedded release smoke, and publish the Windows ZIP as a prerelease. Desktop shortcut script creates two explicit icons using the embedded ship icon. Do not overwrite or terminate a running earlier build. Verify release/download and shortcut targets before reporting publication completion.

## Boundaries

Human full-run balance/fun/audio judgment, physical controller/phone and device frame pacing remain open playtest gates. No automated test proves them. Headless audio teardown may report engine playback references; rendered teardown does not reproduce them.

Preserve unrelated dirty/untracked old captures, trailer sidecars, raw video, shortcut backups and prior notes. Desktop-control Escape is a stop signal: do not resume UI automation without fresh user intent. Source changes do not live-patch the game already running.
