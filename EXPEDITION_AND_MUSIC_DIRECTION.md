# VOID//DAEMON — expedition, racing, and a connected music workspace

October 22, 2026. Exploration brief, not an implemented feature list or a promise
to build three complete games simultaneously. Current survival and lab remain.

The follow-on clarification is fundamental: enemies are a session-born adaptive
substrate, racing is an encounter inside the expedition, and the graphic novel
is a sibling deliverable. [Universe and substrate direction](UNIVERSE_AND_SUBSTRATE.md)
defines that integrated model; the isolated tests below are development fixtures,
not a proposal to split the experience into unrelated menu modes.

## Direction

Move toward intentional space combat and authored journeys, not exclusively a
density race. An overworld connects hubs, bases, checkpoints and missions.
Levels have their own layouts: corridors, rooms, debris channels, facilities,
open pockets, and gravity structures. Authored narrative and music are scaffolded
and curated by the creator. Seeds can vary selected content inside these authored
boundaries; they do not dictate the story or require combat replay determinism.

The separate music-making workspace exports into the game. It is not a large
editor bolted into the combat lab, and shipping the game must not require it.

## First playable: one deliberate encounter, not an overworld first

Build one compact, hand-authored relay facility with two entrances, an interior
obstruction, a gravity well, a capture/disable objective and a clean exit. Try
3–6 active opponents initially, with a fixed reinforcement cap and a visible
objective. Those are starting hypotheses, not production balance targets.

Give each opponent a job: a telegraphed anchor controls a lane, a mobile flanker
pressures positioning, and a vulnerable support sustains the formation. More HP
alone is not the solution: stagger, exposure windows, interruption, displacement
and changing priorities make a longer-lived opponent worth interacting with.
Do not just multiply the existing swarm enemies' health.

The intended loop is read → position → isolate/control → commit → recover.
Graviton's gather/salvo/ARC follow-through should create an opening, not instantly
erase every encounter. Bastion needs beam lanes, Scrapper needs meaningful
displacement, and Redline needs controllable risk. Keep automatic DRIVER/ARC;
measure whether they remove the player's target/position decisions before
changing their rules for this mode. No global nerfs to survival to balance it.

Geometry must support inertial flight: enough braking room, clearly readable
walls, tested collision/sliding and camera limits. Do not rely on the open
arena's boundary clamp as a substitute for facility collisions or navigation.
Off-camera attacks and HUD obstruction remain unacceptable.

Pass only if a player can explain which threat they chose, why movement mattered,
and what an effective combo changed. Fail if waiting for cooldowns dominates,
the same held attack solves every formation, or HP merely prolongs cleanup.

## Then an expedition node slice

Start with a small authored route, not a procedural galaxy:

    HOME DOCK → RELAY FACILITY → CHECKPOINT
                              ↘ SALVAGE DETOUR → GATE BATTLE

Home dock handles chassis/loadout selection, repairs and narrative context.
The relay teaches deliberate combat in real geometry. The checkpoint saves a
completed mission boundary. The detour offers a stated tradeoff, not a hidden
punishment. The gate battle tests learned interactions in an authored arena.

Each node needs a stable ID, layout resource, objective, encounter definition,
entry/exit points, reward contract, music cue and narrative event IDs. Separate
campaign state (unlocks, chosen route, authored flags) from temporary encounter
state. Begin with checkpoint-boundary persistence, not arbitrary mid-fight saves.
Failure/retry rules must be chosen explicitly before implementing campaign saves.

Narrative should have curated scene beats with conditions, priorities, cooldowns
and a seen-event ledger. The hive can react to actual gameplay, but improvisation
must not invent canon or pretend to know personal information. Dialogue stays
subtitle-first; speech and PiP remain optional. Brief before combat; avoid making
the player read consequential choices while dodging.

Scorecards become objective-aware: outcome, objective progress, damage taken,
resource use, precision/control contribution and traversal time where relevant.
Retain real weapon attribution, but don't rank a careful objective win below a
longer farming run on kills or DPS alone. Live inspection remains available.

## Racing: an expedition encounter, proven in an isolated fixture

An original gravity circuit is a good fit for current inertia. The playable
purpose is a pursuit, interception, escape or other encounter in the expedition,
not necessarily a separate mode. An isolated single-ship test track first proves
handling, gates and reset before adding an adaptive pursuer. That fixture is a
development tool, not the proposed final product structure. No rubber-banding,
AI grid or dozens of tracks are required for that test.

Try a broad acceleration straight, a counter-thrust braking corner, a gravity
apex, a slingshot exit and one clearly telegraphed moving obstacle. The fastest
line should involve choosing how much momentum to retain, not holding boost
against invisible rails. Recovery after a mistake should remain playable.

Test handling before calling it a racer: existing combat thrust is screen-relative
and aim-independent, whereas a nose-thrust racing profile is a different control
contract. Compare those profiles explicitly. Do not silently change combat
controls. Keyboard, controller and touch must have usable steering, thrust and
braking, with no mandatory fine mouse aim. Use camera look-ahead and limited
speed-based zoom only after readability is proven.

Keep one fixed ship/profile for the first comparison. Teleport/Backtrace, gravity
control and ship stats can invalidate checkpoints or competitive times; later
ship classes need separate records and explicit maneuver rules. Validate gate
order, direction, finish crossing and respawn behavior. A seed can share track
geometry; don't promise cross-machine deterministic ghost simulation.

If this works, an expedition can include courier runs, chase/escape nodes or an
optional timed salvage route. Combat racing and multiplayer are later separate
bets, not requirements for an interesting traversal mission.

## Separate chiptune instrument IDE: creator-owned composition and curation

The creator's existing compositions are the source, not a prompt to replace them
with unrelated generated music. Preserve originals as immutable source files.
Any edits, samples, motifs or arrangements are distinct versioned works linked
back to the chosen original. No automatic upload or bulk analysis of a music
folder. Explicit import/selection is the boundary.

The smallest useful workspace connects three views:

1. Library/curation: listen, mark regions, add mood/energy/context notes and
   provenance. Separate a listening reference from audio approved for export.
2. Instrument/pattern editor: square/pulse, triangle, noise and wavetable voices;
   envelopes, duty/timbre, limited polyphony, pattern lanes, note entry and a
   transport. Retro character is a creative choice, not forced lossy conversion
   of a mastered song. Samples and extracted motifs require explicit selection.
3. Context audition: use authored game-state fixtures (hangar, coast, swarm,
   objective battle, boss, debrief) to hear the composition with representative
   SFX and hive ducking. This is a mix audition, not proof of a finished game.

First vertical slice: import one selected source, annotate it, build one manual
8–16 bar arrangement with three voices plus noise, audition it, save/reopen it,
and export it into the game's existing local music folder. No automatic audio-
to-MIDI or full DAW replacement required. Source audio need not be decoded inside
the runtime project format; the workspace can keep explicit local references.

Project data should store version, selected source IDs/hashes, annotations,
tempo, patterns, instrument definitions, arrangement and export settings.
Exports should have a rendered Ogg/WAV plus a small versioned cue manifest
(cue ID, intended context, gain/loop information, source/arrangement version).
The current game only consumes full tracks by folder; cue manifests, loop-region
scheduling, stem synchronization and instrument synthesis are future work.

Keep a clean runtime boundary: authoring workspace → validated export pack →
game audio adapter. The game never executes arbitrary editor scripts. Later,
matched-length stems can react to encounter states at musical boundaries; do not
pitch-shift the creator's whole track with ship speed or randomly resequence
compositions without deliberate authoring.

## Build and test order

1. Current pass: non-destructive live stats, local soundtrack playback and
   independent mix controls. Actual supplied music audition remains pending.
2. Encounter slice: prove intentional combat and physical geometry in isolation.
3. Small node route: connect the proven room, one hub/checkpoint and curated beats.
4. Music workspace slice: one source → one authored arrangement → one game export.
   Keep this separately scoped; it can be developed independently of the map.
5. Racing handling test: one circuit. Add it to the map only if traversal is fun.

Human gates remain distinct from automated tests: handling feel, enemy intent,
musical quality, narrative coherence, full-run pacing, physical touch/controller
use and hardware frame pacing. Avoid treating passing serialization or input
tests as proof of those outcomes.
