# First Arrival campaign — desktop-2026.10.29.3

This is a complete playable prototype chapter, not a finished commercial game.
The eleven-mission route measures 19:30–20:54 active simulation across all four
chassis in continuous normal-input tests. Reading and failed attempts are not
added to those totals. Human-feel/device/performance gates remain separate. The
older .1/.2 and October 23 builds remain separate and unchanged.

## Start

Open `VOID-DAEMON.exe`, choose a chassis, then NEW EXPEDITION. Or use `Play
Expedition.cmd`. RESUME CHECKPOINT uses the saved expedition's chassis and build.
Command line: `VOID-DAEMON.exe -- --campaign`; add `--touch-ui` for touch preview.

WASD/arrows thrust, release to coast, counter-thrust to brake. M1 holds/releases
the chassis attack, Shift/Space performs its maneuver. Shield is passive. Left
touch stick/right action pad are unchanged. Esc/P or controller Start opens live
stats; Pause Options includes audio/accessibility, retry and return to hangar.
In Memory Spine, M opens the paused sector map directly; touch uses II then MAP.

## Current connected route

1. Outer Link: destroy the substrate relay, then extract left. MIND shows report
   and movement hypotheses. This is narrow session adaptation, not full ecology.
2. Courier: twelve ordered gates through gravity machinery and solid obstacles.
   Auto weapons are explicitly stowed, not deleted. Beat the courier to deny two
   real picket reinforcements. Finish late and the consequence carries forward;
   miss the 150-second window entirely and retry. Follow the cyan gate arrow.
3. Picket: clear and secure
   three separated positions in any order, then eliminate remaining hostiles and
   extract north. Coast below 85 u/s inside each cleared ring for 1.5 seconds.
   Six opponents, or eight if the courier escaped.
4. Coolant Archive: navigate physical doorways, disable two guarded cores, coast
   in the east archive for three seconds, then return to the west entry. Cores
   warn before discharging. Walls stop targeting, weapon damage and movement.
5. Watchdog: defeat the multi-phase gate defender. This opens the recovery yard.
6. Recovery: three archive carriers are scattered across the yard. Coast below
   80 u/s within 85 units for 1.5 seconds to tether one. Return it to the central
   cradle; a tether stretched beyond 500 units breaks and leaves the carrier
   stranded, not teleported. Banked carriers are safe. Their deliveries draw
   finite reinforcements with at most six live opponents. Resolve every carrier,
   save at least one, clear the attackers and return to the cradle. Cradle loss
   or loss of every carrier fails the mission. Survivors carry into the ending.
7. Memory Spine: nine seeded sites across an expanded sector, visited in any
   order. Destroy three relays; clear and survey three repair sites; retrieve
   three records and return each to the southern cradle. Only one cargo slot.
   Surveys/records require two seconds below 85 u/s in an uncontested ring.
   Repairs are one-use, +20 hull capped. Dock shells physically block movement,
   sight, targeting and shots; use the open sides. Gravity wells are escapable.
   Defenders activate on approach, with at most eight concurrently alive.
   Scouts visibly wind up delayed reports. Kill the scout or its relay before
   delivery to interrupt. Local sight persists after disconnect; remote reports
   expire. Secure all nine sites and return to the cradle to finish.
8. Power District: six connected physical rooms. Recover a numbered cell from a
   north feeder, clear its matching south converter, install, then confirm at the
   south-central bus. One cell cradle; coast below 85 u/s for 1.5 seconds to
   interact. Carrying adds 8 heat/s. Online converters discharge in a 230-unit
   ring every seven seconds, with a 1.5-second red warning. Confirm all three
   circuits and exit southwest. Restored circuits add real transport hull next.
9. Three Voices: escort a damageable transport through seven service checkpoints.
   It holds if you leave its 700-unit escort range or a visible hunter is within
   600. Protect it, use bulkheads for cover, and optionally coast at the one-use
   south-central service ring for +60 capped transport hull. Power adds up to
   150 hull; the departure story can add 60 more in exchange for larger details.
   Clear surviving hunters and rendezvous at the southeast exit. Transport loss
   is an explicit checkpoint failure, not a quietly substituted victory.
10. Warden: destroy two remote conduits to expose one third of its core. Its
    barrier returns with a new pair at the next health boundary. Three phases,
    six conduits, no timed damage window. A huge salvo cannot skip the next
    barrier. Shielded cores are excluded from auto targeting and visibly ringed.
    Clear survivors and extract west after destroying the core.
11. First Arrival: a continuous combat escape, not a separate menu mode. Weapons
    remain live. Pass eleven forward gates in a solid service maze; destroy
    jammers at three gates. A visible collapse front follows the same route at
    145 u/s after twenty seconds and deals repeated contact damage. Receiver
    closes after 300 active seconds; pause freezes the clock. Collisions above
    low speed cost hull. Reach the receiver for the authored chapter ending.

## Progress and checkpoints

This .3 build includes three three-page terminal
story interludes with code-drawn illustrations and saved page positions. These
are newly authored prototype fiction, not approved universe canon or a finished
graphic novel. There is no reading timer and action stays paused. Before the
Watchdog, spoofing a maintenance signature costs 15 hull and reduces escorts from
eight to four; an announced approach repairs up to 15 hull and retains all eight.
Before recovery, broadcasting increases carrier hull by 50 but allows up to three
interceptors per delivery instead of two, still capped at six live attackers.
Silence keeps the original carrier hull and reinforcement budget. Decisions are
committed once and preserved on retry/resume. The older .1 EXE does not contain
these interludes, the distributed picket or Memory Spine.

Before the convoy, linked channels add 60 transport hull but allow four hunters
per checkpoint instead of three (eight-alive cap). Independent channels keep the
standard transport/details and restore up to 15 ship hull. This choice is saved
once, with the same page navigation and retry rules as the earlier interludes.
The .2 EXE has only the first seven missions and first two interludes.

Between completed missions, choose an upgrade or continue without one. Choices
show their effects. A service cradle repairs 25 hull (capped) and restores shield;
patches and ship condition carry forward. Rewards commit once, not on repeated
button activation. Death/retry restores mission-entry state, not a damaged or
partially completed encounter. Returning to the hangar leaves that checkpoint.

The version-2 checkpoint uses stable mission IDs and consequence flags. A changed
route index cannot silently load the wrong mission. Older version-1 draft saves
are rejected without being overwritten by Resume. NEW EXPEDITION deliberately
starts a new route and replaces the campaign checkpoint when deploying.
Completed .1/.2 drafts resume at the first added act (Memory Spine or Power
District as appropriate), retaining earned upgrades and hull. Only a checkpoint
with the actual escaped outcome opens the new chapter ending directly.

The ending's mission-time total counts completed mission simulation time, not
reading, pauses or failed attempts. It is not a certified real-world duration.
Full normal-input pilots complete eleven missions in 19:30 Graviton, 19:58 Bastion,
19:48 Scrapper and 20:54 Redline, with no failed missions. See PLAYTIME_AUDIT.md.
The early sector remains light on combat pressure for an optimized build. These
probes establish approximate content amount and reachable objectives, not final
balance or an enjoyable human twenty-minute session.
Narrative is newly authored prototype material, not imported universe canon or
the completed sibling graphic novel. Your supplied music remains a local-file
audition task; see `music/README.md`.

## What to report

Record build, chassis, input device, completed mission time, retries, confusing
objectives and whether momentum/cover/target priorities mattered. Particularly
check pickup and tether behavior, carrier/cradle survivability, readable failures,
checkpoint restoration, and all chassis in the facility. Physical controller,
phone/touch, accessibility comfort, real listening and frame pacing remain human
gates. Automated route/cover/state tests do not establish those outcomes.
