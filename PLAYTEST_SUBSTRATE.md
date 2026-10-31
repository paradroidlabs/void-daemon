# Substrate relay proof — desktop-2026.10.23.1

This is the first implemented perception/communication/adaptation encounter.
It is not yet the proposed full A-Life ecology, overworld, racer or visual story.

Open **Substrate Encounter / Relay Proof** in the hangar, or select **Substrate
[F9]** in a combat lab. Mouse/touch use the same native selector. The standalone
package also includes `Play Substrate Encounter.cmd`. All four chassis work;
automatic weapons remain active under the existing loadout rules.

Objective: destroy the purple relay on the right, then reach the extraction ring
on the left. Enemies act immediately without waiting for M1. No reinforcements
are spawned. There are two scouts, a ranged anchor, one charging flanker and a
stationary relay. Existing swarm/survival behavior is unchanged.
The relay is anchored against gathering/knockback; the four mobile agents are not.

## What to try

1. Move near the scouts. They shadow or patrol; dotted packets indicate pending
   reports. Reports take at least 1.25 seconds and need a live source, relay,
   signal path and radio range. A blocked packet expires after two more seconds.
2. Kill a scout while its report is pending, or cross the marked sensor shadow.
   The shadow is non-solid sensor interference, not physical cover. It blocks
   perception and radio paths, not bullets, movement or auto-targeting.
3. Give the scouts repeated sightings of a similar travel direction. A hypothesis
   needs six delivered moving reports, at least 67% directional agreement and
   evidence no older than eight seconds. These are scout samples, not six
   statistically independent completed maneuvers. Standing still cannot teach
   a movement hypothesis. Outrunning perception can also deny intelligence.
4. When a hypothesis qualifies, the flanker predicts at most 180 world units
   ahead of a delivered sighting. The real charge has a one-second fixed warning,
   a locked direction and recovery; it cannot retarget a hidden maneuver.
5. Break sight, vary behavior or wait out the evidence. Inspect whether the old
   hypothesis disappears. Destroying the relay clears squad tracking, pending
   reports and shared beliefs. Nearby surviving enemies still have local senses.
6. Press Esc/P (controller Start, touch II) and select **MIND**. The paused snapshot
   shows objective, report counts, evidence and live unit tasks. Resume preserves
   the encounter. Extract for the final card. R resets the lab outside inspection;
   the new session must start with no retained intelligence.

## Current boundaries

Perception samples every 0.2 seconds within 440 units. Radio range is 620 units.
Shared sightings expire after 2.5 seconds from observation, not from delivery.
Agents do not receive a live player target node. Decisions use recent local
observations or delivered reports. No input prediction, personal data, model,
network, disk-based player profile or learning between resets is involved.

Coordination is currently complementary fixed roles using shared sightings, not
general squad planning. The narrow learned feature is travel direction, not
weapon/build recognition or online neural training. Patrol/guard routines are
the initial autonomous behavior, not a resource economy. Navigation around solid
facilities and synchronized breach maneuvers are not implemented.

`tests/substrate_test.gd` covers report provenance, range/occlusion, dead/freed
sources, radio interruption, old evidence, bounded prediction, real locked charge
telegraphs, objective gating, pause/reset and legacy fixture isolation. The visual
demo uses a controlled sensing fixture, not a human playthrough or FPS benchmark.
Whether the behavior reads as intelligent, fun and fair remains a hands-on gate.
