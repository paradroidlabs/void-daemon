# VOID//DAEMON — a living opposition, a playable universe, a graphic novel

Implementation note, October 23: the first narrow relay perception/reporting/
movement-adaptation encounter is now playable; see PLAYTEST_SUBSTRATE.md. The
larger universe/ecology/story direction below remains a design brief. Its final
"present code" boundary describes the October 22 checkpoint, not today's proof.

Direction captured October 22, 2026. This is design scaffolding, not implemented
AI, approved universe canon, or a claim that existing narrative archives were
already imported. It incorporates the creator's clarifications after the first
expedition/music brief.

## The central promise

Each expedition is a contest between the player and the substrate instantiated
for that session. It is not merely a wave director matching player damage.
Enemies act, observe, communicate, pursue local goals and coordinate. The player
can learn about the opposition, feed it misleading information, break its links,
and change the conditions under which it operates.

The wider deliverable is a universe expressed through two sibling works: a game
and a graphic novel or equivalent authored visual narrative. Neither is filler
for the other. The game supplies agency and systemic encounters; the novel can
provide interiority, viewpoints and history that real-time combat cannot.

Survival is an existing sandbox, not the limit of the identity. Hubs, constrained
facilities, deliberate battles, pursuit/racing encounters, quiet salvage and
graphic-novel sequences are different situations in one expedition.

## What A-Life-level intelligence needs to mean in play

Do not claim a full artificial-life ecosystem because a director chooses a
counter to the current weapon. Start with four connected responsibilities:

| Layer | Responsibility | What the player can affect |
|---|---|---|
| Ecology | Resources, relays, repair, territorial control and unit goals independent of immediate player contact | Interdict supply, divert scavengers, destroy/reprogram a relay |
| Agents | Perception, movement, attack timing, survival and local decisions | Hide, flank, interrupt, bait, deny a firing lane |
| Coordination | Shared sightings, complementary roles, reservations and group maneuvers | Isolate scouts, split a formation, jam or delay information |
| Session adaptation | Form and revise hypotheses from observed outcomes | Change tactics, feint a pattern, exploit the cost of an enemy response |

An off-screen group should be able to do something meaningful without a player:
escort salvage, repair a node, contest a route, or retreat. Distant regions can
use coarse simulation; nearby agents need actual interactions. Both must share
consistent resource and state rules. Do not simulate thousands of independent
minds in the first build or pretend unobserved areas need frame-by-frame physics.

For the initial prototype, use explicit agent state/utility decisions, local
perception, a bounded squad blackboard and a small session hypothesis model.
Online neural-policy training or a live LLM is not required for adaptation. A
language model writing a taunt is not evidence that an enemy learned anything.

## Learning without cheating

Use only observable, in-game behavior: visited lanes, recent attack ranges,
charge/release windows, retreat direction, repeated drift arcs, maneuver timing,
target choices and which squad tactics succeeded. Require repeated evidence,
store confidence and recency, and decay stale beliefs. No personal files,
microphone, other apps or cross-run profile by default.

Knowledge needs a source. A scout sees a maneuver, survives and reports through
a relay; that report becomes available to its connected group. Disrupting the
report should matter. Separate omniscient simulation state from what a squad is
allowed to know. A targeting system must not read an unrevealed input command or
future position and call that prediction.

Example: the substrate observes several long Graviton holds in the same orbit.
It estimates a charging window and commits a flanker with a relay-supported
screen. The response is visible and costs formation coverage. The player can
release early, drag the flanker into a pull, change orbit, or attack the exposed
relay. If that fails repeatedly, the substrate must revise its hypothesis rather
than always choosing the same hard counter.

Smart opposition is not omnipotent opposition. Give it limited sensing, response
time, communication, maneuver resources and decision errors. Avoid hidden HP
inflation, perfect projectile dodging, instant elemental immunity, or spawning
an exact counter directly behind the ship. Telegraphed adaptation should change
the tactical question while leaving a meaningful answer with the current kit.

Use budgets and coordination reservations to prevent accidental combinations
that eliminate all readable responses. Difficulty can change reaction windows,
doctrine and resource availability; it should not silently remove the rules.

The hive's intentional voice can reveal its beliefs: “You return to that orbit.”
Only choose that line when a corresponding observation exists. It can be wrong
in fiction if the underlying hypothesis is wrong; it must not fabricate a fact
about the player. Debug inspection should show evidence, confidence, chosen
response, cost and outcome. Fictional mystery must not prevent developer audit.

## Session identity and seeds

The seed can initialize geography, starting ecology and a substrate doctrine
(for example cohesion, caution, exploration and resource conservation). Doctrines
are starting tendencies, not four static enemy skins. The session's observed
history changes later behavior, so identical seeds need not produce identical
fights after different player actions.

Keep initial-content generation separate from reactive decisions. Stable node
IDs and isolated random domains remain useful. This does not require bit-identical
physics replay or promise identical adaptive outcomes after divergent combat.
Checkpoint persistence eventually needs substrate beliefs/resources as well as
player and route state. New session means a new opponent memory by default.
Any later continuity between runs needs an explicit fiction and player-facing
contract, not accidental telemetry retention.

## Encounters are world events, not disconnected minigame buttons

A race can emerge because the substrate is moving something valuable, trying to
cut off an exit, or pursuing the player's extraction craft. Gravity and momentum
become the main interaction for that sequence. Surviving scouts, disabled relays,
available routes and ship condition can affect it.

Examples to prototype, not established lore:

- Interception: overtake a relay courier through a debris channel; destroying
  it stops a report reaching a later encounter.
- Escape: a facility fails and a pursuit follows the player into a gravity lane.
  The opponent predicts a familiar route, which can be used as bait.
- Contested transit: choose a safer braking route or a risky slingshot that gains
  position but leaves the ship exposed. Opponents use the same bounded thrust
  rules, not unexplained catch-up acceleration.
- Quiet recovery: salvage or repair after the chase, giving room for dialogue
  and allowing the world state to change without another swarm spawn.

Preserve the core handling contract or clearly teach a deliberate local change.
Do not silently swap controls, erase a build, or replace a maneuver with a QTE.
The initial test can lock maneuver rules to protect checkpoint validity; the
finished encounter should explain restrictions in-world. Carry state across the
transition where sensible rather than treating each event as a disconnected
arcade score screen.

Graphic-novel passages can open at a hub, an arrival, an aftermath, a discovery
or a consequential conversation. They can present authored pages/panels, choices,
sound and alternate viewpoints. Critical reading happens with action suspended;
there must be no requirement to read lore while avoiding lethal attacks. Give
players a later readable record rather than making meaning depend on catching
a fleeting transmission. Not every encounter needs a story interruption.

## One shared narrative foundation, two complete expressions

Build a shared story bible before generating a large volume of prose:

- Universe rules and explicit unknowns: what the substrate is allowed to do,
  what identity/death/continuity mean, and which questions remain unanswered.
- Entities with stable IDs: characters, factions, places, technologies and
  recurring visual/music motifs.
- Timeline and causal events: what happened, who knows, whose account conflicts,
  and which source supports the claim.
- Story units: scene/chapter/mission IDs, viewpoint, dramatic purpose, entry
  conditions, choices, consequences and related game encounters or novel pages.
- A decision ledger: creator-approved decisions, rejected alternatives,
  open questions, provenance and revision links.

Separate three truth levels. World canon is creator-approved and common to both
works. An authored chapter continuity is a specific telling. A run record is what
actually happened in one playthrough. A clever emergent encounter may inspire a
novel scene, but a generated run summary does not automatically become canon.
Exploratory prose, enemy beliefs and unreliable testimony are labeled as such.

Do not force the novel to transcribe every branch of the game, or make the game
depend on the reader knowing a separate volume. Let a shared event be experienced
through play and understood differently through another character's viewpoint.
Choose the relationship of conflicting playthroughs to authored continuity
before turning repetition into a literal world-law. That metaphysics is open.

## Reuse the creator's narrative workflow, not an invented substitute

Apply the documented principles already used in the creator's narrative work:
preserve original material, retain versioned checkpoints and provenance, separate
author feedback from assistant interpretation, keep decisions linked, and make
the next creative test explicit. Those principles do not authorize copying
unrelated manuscripts or promoting earlier game experiments to universe canon.

Before integration, inventory the actual current workflow/templates and select
which ones the creator wants carried forward. Existing workflow facts here are
memory-derived, not a fresh Notion audit. Preserve raw source separately from
adaptation. Read back saved material; missing source must stay missing, not be
reconstructed and presented as an original. No external archive was modified in
this pass.

For each shared story unit, capture the canonical source and revision, dramatic
question, participating entities, game expression, novel expression, music cue,
creator feedback, approvals and next test. Build adapters/exports from those
records rather than duplicating independent lore bibles that drift apart.

The separate chiptune workspace joins at the same unit IDs: original composition
→ selected motif/arrangement → context audition → versioned audio export. A
musical identity can span a character's page, a hub and a pursuit without the
game arbitrarily rearranging a finished composition.

## The first proof should demonstrate the relationship

Make one small shared chapter, not a campaign framework first:

1. Arrival page/scene establishes a question and an actionable objective.
2. A relay encounter has a scout, a protector and a flanker with real perception
   and coordination. The player can disrupt a report.
3. A repeatable observed tactic can produce one visible, bounded adaptation.
   A counter-test proves it can be baited or defeated.
4. A pursuit/interception consequence uses the same flight physics in authored
   geometry. Success changes a specific later state, not just a race grade.
5. A short aftermath page explores another viewpoint and records the outcome.
   One creator-authored music cue is auditioned across the sequence.

Before this combined slice, validate the agents and handling independently.
Then ask whether the chapter feels like contesting an intelligible opponent in
a place with meaning, rather than five unrelated demos attached to one menu.

Automation should test perception boundaries, report delay/jamming, evidence
threshold/decay, coordination limits, reproducibility from controlled inputs,
checkpoint state, valid route gates and narrative conditions. A scenario where
the player is absent tests whether the ecology has its own goals. A feint scenario
tests whether adaptation follows observations rather than hidden build tags.

Human tests must separately establish perceived intelligence/fairness, surprise,
handling, emotional/narrative coherence and whether the game and visual story
each feel worth engaging with. The present code has none of these AI/world/story
systems yet; its validated live scorecard and music playback are supporting
infrastructure, not evidence of that larger promise.
