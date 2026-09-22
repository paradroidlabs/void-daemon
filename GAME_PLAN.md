# VOID//DAEMON

## Game design and production plan

**Genre:** top-down space survivors-like / bullet heaven  
**Run length:** 20 minutes of survival, roughly 22–25 minutes including bosses and route decisions  
**Target:** PC first; keyboard, mouse, and controller  
**Camera:** fixed top-down, landscape 16:9  
**Working fantasy:** a salvage craft boots forbidden combat daemons while crossing a corrupted machine network at the edge of space.

> Pilot an auto-firing ship through shareable, seed-compiled sectors. Install live code patches that change how weapons behave, then defeat the system processes guarding the route to the Black Kernel.

The main differentiator is not “more upgrades.” It is a small, readable weapon grammar in which each upgrade changes geometry, timing, targeting, triggers, or resource flow. The same weapon can become a different build depending on the patches installed and how the player used it.

---

## 1. Product pillars

### 1. Builds visibly mutate

Most upgrades must change play, not merely increase a number. Projectiles fork, return, orbit, capture hostile fire, collapse into gravity wells, or trigger when the reactor vents. By the midpoint, the player should be able to describe what their build *does*, not just how much damage it deals.

### 2. Space is a place, not a backdrop

The player navigates debris fields, ion lanes, relay grids, anomalies, and optional landmarks. Route choices change the next sector’s hazard, enemy bias, and reward pool. Movement and map knowledge remain relevant after the build becomes powerful.

### 3. Seeds are a reliable contract

A run code reproduces its route graph, layouts, hazards, encounter deck, bosses, and reward candidates. Players can share a notorious seed, race a daily seed, or retry a failed route and deliberately make different choices.

### 4. The terminal style communicates

Processes, patches, compiler logs, warnings, and glyph silhouettes reinforce the fiction while making mechanics easier to read. CRT effects are seasoning, never an obstacle.

### 5. Pressure comes from combinations

Difficulty grows through formations and interacting enemy roles rather than inflated health. Bosses test movement and target priority, with no damage-type immunities or unavoidable hard counters.

---

## 2. The player promise

Within one run, the player should experience this arc:

1. **Boot:** survive with one clear weapon process and learn movement and `VENT`.
2. **Assemble:** install two or three processes and choose the first behavioral patches.
3. **Compile:** use a boss key to transform a process based on its patches and visible run telemetry.
4. **Cascade:** combine processes so one system feeds another and the screen becomes spectacular without becoming illegible.
5. **Root:** defeat a final boss that disrupts the build just enough to demand movement and adaptation.

A successful run should feel authored by the player, even though its world and offer sequence came from a seed.

---

## 3. Run structure

### Run signature

Every run starts from a base signature:

```text
SEED + RULESET_VERSION + DIFFICULTY + UNLOCK_MANIFEST
```

Example:

```text
A7F3-K9D2 / v1 / THREAT-2 / STANDARD
```

The completed run appends a route suffix such as `/ L-R`, recording choices at jump gates. An official daily run locks the chassis, unlock pool, ruleset, and difficulty so scores are comparable.

### Three-sector flow

The survival clock pauses for gate bosses, the final boss, and short command phases.

| Survival time | Phase | Purpose |
|---|---|---|
| 0:00–2:00 | `BOOT` | Establish the sector, basic fodder, first upgrade within 20–30 seconds |
| 2:00–5:30 | `ASSEMBLE` | Add one specialist enemy, a landmark, and the first meaningful synergy |
| 5:30–6:00 | `GATE WARNING` | Crescendo, reward vacuum, clear boss telegraph |
| 6:00 | Gate boss 1 | Test one movement skill; award a `ROOT KEY` |
| Command phase | Route + compile | Choose one of two sectors, repair slightly, compile or reroute a process |
| 6:00–13:00 | Sector 2 | Combine two enemy roles and a stronger environmental hazard |
| 13:00 | Gate boss 2 | Test target priority and build coverage; award a second key |
| Command phase | Route + compile | Choose the final route and commit the build’s capstone direction |
| 13:00–20:00 | Sector 3 | Full compositions, elites, and an optional high-risk anomaly |
| 20:00 | Final boss | Three-phase fight; victory ends the run |

The two route options reveal:

- biome and environmental hazard;
- dominant enemy family;
- reward bias, such as `[KINETIC]`, `[DRONE]`, `[HEAT]`, or `[DEFENSE]`;
- one unknown anomaly slot on higher difficulties.

This is an informed strategic choice, not a blind door.

### Moment-to-moment loop

1. Read the next formation, sniper line, hazard, or elite tell.
2. Steer through an opening while weapon processes execute automatically.
3. Optionally bias targeting toward a priority threat.
4. Route through wreck-data and useful landmarks.
5. Redline the reactor for output, then `VENT` to recover space or trigger synergies.
6. Level up every 25–45 seconds and install one meaningful patch.
7. Defeat the gate process, compile the build, and choose the next route.

---

## 4. Controls and ship model

### Controls

| Input | Action |
|---|---|
| WASD / left stick | Move with immediate steering and a slight inertial tail |
| Mouse / right stick | Optional target-priority cone; release to return to nearest-threat targeting |
| Space / shoulder button | `VENT`: dump heat, emit knockback, and phase briefly through contact damage |
| Esc / Start | Pause and inspect the build, map, seed, and glossary |

The game remains fully playable with movement plus one action. Manual targeting improves precision but is never required.

### Survivability

- **Shield** absorbs a small number of mistakes and regenerates after avoiding damage.
- **Hull** is persistent health and requires repair drops, landmarks, or boss recovery.
- Contact damage has a short grace period; overlapping enemies cannot delete the player in a single frame.
- Pickups have a generous base vacuum radius. Collection range is a bonus, not a mandatory “magnet tax.”

### Reactor heat and `VENT`

Weapon processes create heat. A normal starter configuration stabilizes below roughly 65%; heat becomes a real constraint only when the player deliberately adds overclock effects.

- High heat can amplify `[HEAT]` patches.
- At 100%, processes soft-throttle instead of shutting off completely.
- `VENT` has an approximately six-second base cooldown.
- Its knockback and related patch effects scale with heat dumped.
- It grants about a quarter-second of phasing, enough to cross a telegraphed line but not ignore a formation.

Heat creates an expressive risk loop without turning basic auto-fire into maintenance work.

---

## 5. Dynamic upgrade system

### Vocabulary

| Term | Meaning |
|---|---|
| `PROCESS` | An auto-running weapon or defensive system; four slots maximum |
| `PATCH` | A behavioral modifier installed into a process; two normal patches per process |
| `DAEMON` | A global passive rule; three slots maximum |
| `COMPILE` | A major transformation created from a process, its patches, and qualified behavior |
| `ROOT KEY` | A boss reward used to compile, reroute, or unlock a capstone |
| `TAG` | A rules label such as `[KINETIC]`, `[ARC]`, `[HEAT]`, `[DRONE]`, or `[GRAVITY]` |

### Weapon grammar

Each patch has five parts:

1. a target process or system;
2. a behavioral verb such as `FORK`, `CHAIN`, `ORBIT`, `CAPTURE`, `RECALL`, `MARK`, or `CONVERT`;
3. a trigger such as `ON_HIT`, `ON_KILL`, `ON_VENT`, `ON_SHIELD_BREAK`, or `ON_COLLAPSE`;
4. a visible cost, limit, or tradeoff;
5. tags that enable later cross-process synergies.

Patches are curated through a shared ruleset, not assembled from arbitrary procedural text. Not every patch must work with every process. The launch target is at least 48 deliberately supported process-patch pairings.

### Level-up offer

Each level pauses play and presents three cards:

1. **Compatible:** immediately improves or extends an installed process.
2. **Synergy or coverage:** connects tags, fills a weakness, or advances a compile condition.
3. **Branch:** a new process, daemon, defense, economy option, or risky overclock.

Rules:

- Start with two rerolls; elites can restore them.
- The player may cache one card until the next level.
- There is always at least one legal, build-relevant option.
- A defensive or mobility option enters a pity pool after several levels without one.
- Maxed or excluded cards never appear.
- Offers are derived from `(seed, level index, choice history, reroll index)` and remain reproducible.

### Adaptive compilation

At each gate, the compiler exposes branches based on both installed patches and visible usage counters. It never makes a hidden choice for the player.

Examples:

```text
LINE_DRIVER     18 / 25 shots pierced 3+ contacts
REDLINE         21 / 30 seconds spent above 80% heat
PURGE_LOOP      14 / 20 kills within 1.5 seconds of VENT
SALVAGE_FORK    38 / 50 wrecks consumed by drones
```

Meeting a condition unlocks or discounts a specialized branch. A general-purpose branch is always available, so accidental play cannot trap a build. This makes the upgrade system respond to how the player fought while remaining understandable and deterministic.

If no process qualifies when a `ROOT KEY` drops, the command phase offers a guaranteed compatible patch or lets the player bank the key. A boss reward never becomes unusable because of earlier offer luck.

### Guardrails

- At least 70% of normal patches alter geometry, targeting, cadence, triggers, movement, or resource flow.
- No standalone `+10% damage` cards in the normal level-up pool. Small stat changes may accompany behavior.
- Ordinary unconditional stat accumulation should remain in the 20–30% range.
- Proc-spawned effects receive a `child` flag and cannot recursively trigger their parent.
- Chain depth, active children, and simultaneous effects have explicit caps.
- Percentage-health effects use boss coefficients; bosses are not simply immune.
- Every card states its exact behavior and downside, plus a plain impact preview such as `coverage ↑ / heat risk ↑`.

### Example process roster

| Process | Base behavior | Spatial question |
|---|---|---|
| `MASS_DRIVER` | Slow, high-force piercing round | Can the player align several targets? |
| `ARC.EXE` | Short-range chain lightning with high heat | Is diving into a dense pack worth the risk? |
| `GRAVITY_GC` | Periodic compression well | Can enemies and effects be grouped before collapse? |
| `DRONE.FORK` | Maintenance drones collect, intercept, and ram | Should drones protect the ship or consume wrecks? |
| `LASER.PING` | Beam ramps while contact is maintained | Can the player hold a target in the priority cone? |
| `MINE.DEPLOY` | Mines drop along the ship’s recent path | Can movement lay an effective route? |
| `ORBITAL.DEF` | Close orbitals damage contacts and screen shots | Can the player skim a formation safely? |
| `PACKET_FILTER` | Captures a capped number of hostile projectiles | When should stored fire be released? |

### Example compile outcomes

| Inputs | Compile | Result |
|---|---|---|
| `MASS_DRIVER + FORK_ON_KILL + RETURN_VECTOR` | `LOOPBACK ROUND` | Rounds that leave range return through the ship toward a new target; `VENT` recalls all active rounds |
| `ARC.EXE + CONDUCTIVE_MARK + GRAVITY_GC` | `EVENT HORIZON BUS` | Contacts in a well share arc hits; collapse releases stored chains |
| `DRONE.FORK + SALVAGE_DAEMON` | `REPLICATION LEAK` | Drones consume wrecks to create temporary children; `VENT` expires them as small bursts |
| `PACKET_FILTER + VENT_AMPLIFIER` | `RETURN TO SENDER` | Captured hostile shots retarget and fire during `VENT` |
| `MINE.DEPLOY + GRAVITY_GC` | `TRASH COMPACTOR` | Wells ingest nearby mines and combine them into one delayed collapse burst |

The transformations deliberately join systems. A great build should feel like a machine, not a stack of independent guns.

---

## 6. Seeded sectors

### Sector construction

Each sector is assembled from authored chunk templates, then decorated and connected deterministically.

1. Select the sector biome and hazard profile from the route node.
2. Place a safe start chunk and two or three landmark chunks.
3. Connect them with traversable open-space corridors.
4. Fill remaining coordinates from the biome’s chunk deck using rotation, mirroring, and seeded decoration.
5. Place anomalies, debris, hazard emitters, and ambient details through coordinate-keyed rolls.
6. Validate clearance, reachability, hazard coverage, and boss space.
7. If validation fails eight bounded attempts, load a seeded safe template.

Generation should favor authored combat spaces over algorithmic novelty. A finite 7×7 chunk sector is enough for the vertical slice; the full game can tune dimensions after movement-speed testing.

### Fairness constraints

- The start has a clear disk at least 1.5 screens wide.
- Obstacles cover no more than roughly 18% of traversable space.
- Passages are at least 2.5 times the craft width.
- Encounter cells expose at least two independent escape routes.
- Required objectives never demand crossing an active damage field.
- Normal enemy entry is between 1.1 and 1.8 screens from the player.
- Off-screen rail or charge attacks first draw a full-brightness line into view.
- Boss arrival drains normal waves, clears old mines, and creates a clean opening tell.

### Biome pool

| Sector | Identity | Fair hazard |
|---|---|---|
| `SCRAP ORBIT` | Wreckage, salvage fields, broken hulls | Slow drifting cover; broad openings remain |
| `ION SEA` | Sparse charged debris and luminous lanes | Lanes charge visibly for two seconds before arcing |
| `GRAVE RING` | Asteroid clusters and narrow fronts | No sealed pockets; every cluster has multiple exits |
| `RELAY LATTICE` | Satellites and open geometric corridors | Temporary laser walls always display a usable gate |
| `COMET WAKE` | Diagonal moving debris formations | Trails slow enemies and player equally |
| `NULL CLOUD` | Low-contrast scan field and sensor ghosts | Distant bodies fade, but hitboxes and attack tells stay bright |

The first sector comes from the forgiving `SCRAP ORBIT` family. Route choices use the other biomes without repeating the same environment in one run.

### Landmarks and anomalies

Landmarks make navigation matter without turning survival into a quest checklist.

| Landmark | Risk/reward |
|---|---|
| `SALVAGE RELAY` | Stay nearby while it boots; receive a cache or reroll |
| `BLACK BOX` | Spawn a labeled elite protocol; reveal a compile-biased reward |
| `REPAIR DOCK` | Spend salvage or defend briefly to restore hull |
| `DISTRESS PING` | Rescue a drifting drone for a temporary daemon |
| `QUARANTINE NODE` | Enter a denser local wave for a rare patch candidate |

The player can ignore all optional landmarks and still finish the run.

### Deterministic encounter director

Use curated wave cards instead of unconstrained random spawning:

```text
FLOOD · PINCER · FIRING_LINE · ESCORT · MINEFIELD · SPIRAL
```

Each card declares its time window, threat budget, enemy roles, formation, elite chance, concurrent caps, and incompatible hazards. The seed orders eligible cards; the director spends their budget according to the current phase.

Hard composition rules prevent unreadable situations. For example:

- no more than two `TETHER` contacts at once;
- never combine a tractor pull, mine wave, and sniper barrage;
- at most three or four specialist roles beside basic fodder;
- support and projectile counts have fixed readability caps;
- difficulty may shorten generous tells, but never below a tested floor.

Enemy health does not secretly scale in response to the player’s build.

### Determinism contract

The v1 promise is deterministic *content*, not necessarily a bit-identical combat replay across every machine.

Derive independent random streams with a stable project-owned hash and version-locked PRNG:

```text
layout       = H(seed, ruleset, "layout", sector, route)
chunk(x, y)  = H(seed, ruleset, "chunk", sector, route, x, y)
waves        = H(seed, ruleset, "waves", sector, route)
boss         = H(seed, ruleset, "boss", sector, route)
upgrade(n)   = H(seed, ruleset, "upgrade", level_index, choice_history)
loot(event)  = H(seed, ruleset, "loot", stable_event_id)
cosmetics    = H(seed, ruleset, "cosmetics", coordinate)
```

Never use one global random stream. Skipping a landmark must not change a later boss, and a cosmetic particle must never perturb an upgrade offer. Sort all candidate sets by stable ID before choosing. Store the generator version and content manifest with each run result.

---

## 7. Enemy language

Every enemy has one primary job, one readable glyph/silhouette, and one clear counteraction.

| Contact | Role | Counterplay |
|---|---|---|
| `BIT [.]` | Basic swarm drone | Route through or clear in bulk |
| `VECTOR [>]` | Draws a lane, then dashes after a 0.8-second tell | Cross the line early or step aside late |
| `RING [o]` | Orbits and slowly tightens a formation | Exit through its deliberately wide gap |
| `SENTRY [^]` | Anchors at range and tracks a rail line | Break the line or prioritize the sentry |
| `TETHER [=]` | Applies a mild pull through a visible cable | Break distance or kill either tether |
| `SEEDER [*]` | Drops mines along the player’s wake | Change route; mines arm slowly and expire |
| `BULWARK [#]` | Slow unit with a frontal plate | Flank it or use penetration and area effects |
| `HOST [%]` | Carrier with marked launch bays | Destroy bays or burst the host; child count is capped |
| `SCAVENGER [$]` | Collects loose data and grows | Hunt it to reclaim the full haul plus a bonus |
| `FIREWALL [{ }]` | Linked pair shielding nearby contacts | Destroy a node or pass through the moving gap |

### Introduction rules

- Introduce one role alone before combining it with another.
- Add a new specialist at the start of a phase, not in the middle of peak density.
- Elites receive one labeled modifier: `ARMORED`, `VOLATILE`, `RECURSIVE`, or `BLINK`.
- Never stack unlabeled elite traits.
- Use soft counters only. Every build can damage every enemy.

### Power curve

Target approximately 8–12× growth in kill throughput over a run, but only about 3× growth in raw survivability. Pressure rises through density, speed, formations, hazards, and role combinations before it rises through health.

---

## 8. Bosses

Two gate bosses are selected from a compatible seeded pool. The Black Kernel is the final encounter.

| Boss | Core test | Attacks and openings |
|---|---|---|
| `WATCHDOG_01` | Lane reading and `VENT` timing | Rotating laser spokes with a generous gap; marked lunge; long exposed cooldown |
| `CARRIER CTRL` | Priority targets and area coverage | Drone cones and orbiting shield pods; hull is always damageable, pods create faster openings |
| `GARBAGE COLLECTOR` | Positioning around gravity | Pulls loose data and fodder into itself; purge attack exposes the core and returns stolen data |
| `MIRROR PROCESS` | Deliberate pathing | Replays the player’s path three seconds later as a damaging ghost trail |
| `BLACK KERNEL` | Full build and sustained movement | Grid-gap phase, capped gravity adds, then moving safe wedges and recurring core exposure |

### Boss rules

- Fixed health by difficulty; never scale to the current build.
- No damage-type immunity.
- Alternate near and far openings so contact and ranged builds remain viable.
- Maintain capped fodder so on-kill, salvage, and chain builds still function.
- Telegraph first, then overlap patterns only after the player has seen them separately.
- A temporarily quarantined process can be restored by destroying a visible terminal node; a boss never deletes an upgrade.
- Long fights use capped soft pressure rather than an instant-kill enrage.

On higher threats, a boss receives one visible compatible protocol such as `SATELLITES`, `REPAIR_RELAY`, `MINE_LEAK`, or `POST_ATTACK_BLINK`. The final boss can receive two.

---

## 9. Terminal art and audio direction

### Visual language

The playfield should use crisp vector-like sprites and bold glyph silhouettes rather than literal tiny ASCII art. The UI can be more explicitly terminal-like.

| Meaning | Default color | Redundant cue |
|---|---|---|
| Player and friendly systems | Cyan | Solid outline and circular core |
| Data and positive rewards | Green | Inward pulse |
| Warnings and interactables | Amber | Dashed frame and countdown |
| Standard threats | Red | Angular silhouette |
| Boss and anomaly systems | Magenta | Double outline and unique tone |
| Neutral structure | Dim white/gray | Static line work |

All critical states also use shape, motion, labels, or audio. Color alone never carries a mechanic.

### HUD sketch

```text
┌─ VOID//DAEMON ─ SEED A7F3-K9D2/L ─ T+08:42 ─ THREAT 02 ───────┐
│ HULL  [██████░░]   SHIELD [███░]   HEAT [███████░░░]  VENT:RDY │
│                                                               │
│                         PLAYFIELD                             │
│                  glyphs + vector effects                      │
│                                                               │
├─ PROC 01 MASS_DRIVER.R3 ─ FORK_ON_KILL ─ RETURN_VECTOR ───────┤
│ PROC 02 GRAVITY_GC.R2  │ DAEMON: SALVAGE │ LOG: GATE @ 00:41  │
└───────────────────────────────────────────────────────────────┘
```

The actual HUD should be lighter than the sketch: use negative space and show the full log only when relevant.

### Presentation rules

- Keep the gameplay layer clean; reserve dense terminal chrome for menus and command phases.
- Text remains crisp even when the world layer distorts.
- Glitches punctuate transitions, boss phase changes, and compile events; they are not constant noise.
- Scanlines, bloom, curvature, chromatic offset, flicker, hit flash, and screen shake each have independent sliders or toggles.
- Provide UI scaling, large-text mode, high-contrast palettes, reduced-flash mode, and full input remapping.
- Use captions and directional indicators for important off-screen audio cues.

### Sound

- Processes have distinct synthetic rhythms so the build becomes an audible machine.
- Warnings use short, consistent modem/relay motifs instead of generic alarms.
- `VENT` provides the strongest low-frequency release in normal play.
- Music adds layers as processes compile, then strips them away before a boss command starts.

---

## 10. Meta progression and replayability

Meta progression expands possibility instead of selling back lost power.

### Unlocks

- four chassis with distinct starting processes and rules;
- new processes, patches, and daemon pools;
- biome routes and optional anomalies;
- explicit `THREAT` protocols;
- terminal palettes, boot sequences, ship shells, and log themes;
- seed archive, run history, and codex entries.

Suggested chassis:

| Chassis | Identity |
|---|---|
| `COURIER` | High thrust; `VENT` briefly accelerates movement |
| `BASTION` | Larger shield; begins with `PACKET_FILTER` |
| `SCRAPPER` | Drone and salvage interactions; excess repairs convert into temporary drone charge |
| `REDLINE` | Strong heat bonuses and faster throttle onset |

Avoid permanent numerical power in shared-seed modes. If a campaign layer later adds small stat bonuses, official daily runs and leaderboards use a normalized manifest.

### Replay hooks

- Shareable seed and route string.
- Daily run with normalized content and a fixed chassis.
- Explicit difficulty protocols, such as extra elites, faster hazards, or limited repairs.
- Post-run terminal printout with seed, route, bosses, protocols, anomalies, build checksum, and cause of death.
- Endless mode only after the standard run is proven and balanced.

---

## 11. Technical architecture

This plan is engine-agnostic. Use the team’s fastest proven 2D engine and pin its version before public seeds ship.

### Runtime boundaries

```text
RunController
├── SeedService + RunDescriptor
├── SectorGenerator + ChunkStreamer
├── SpawnDirector + BossDirector
├── CombatSimulation
├── UpgradeCompiler
├── ContentDB
├── SaveService
└── Presentation + HUD + Audio
```

- Keep simulation, presentation, content definitions, and persistence separate.
- Run player, boss, and authoritative combat logic on a fixed tick.
- Interpolate presentation; update distant swarm steering less frequently.
- Use ordinary scene objects for the player, bosses, landmarks, and UI.
- Store hordes, projectiles, pickups, and damage queries in pooled manager-owned arrays or another proven data-oriented structure.
- Use a uniform spatial hash for local collision and targeting queries.
- Pass typed combat events through a per-tick queue instead of broadcasting thousands of object signals.
- Never serialize the live scene tree as a save format.

### Core data definitions

| Definition | Required data |
|---|---|
| `RunDescriptor` | seed, ruleset version, generator version, content hash, difficulty, manifest, route |
| `ProcessDef` | stable ID, tags, targeting, cadence, base effect, heat, compatible operation hooks |
| `PatchDef` | stable ID, trigger, operation, parameters by tag, costs, prerequisites, exclusions, caps |
| `DaemonDef` | global event hook, operation, tags, stacking rule |
| `EnemyDef` | stats, shape, steering role, attack, drops, threat cost, presentation IDs |
| `WaveCard` | phase window, budget, formation, role weights, caps, incompatibilities |
| `SectorDef` | generator version, chunk deck, landmarks, hazards, wave table, boss pool |
| `BossDef` | phases, attacks, telegraphs, cooldowns, add caps, protocols, rewards |

All content uses permanent string IDs and schema versions. Saves must not depend on file paths, resource order, or enum ordinals.

Stat operations apply in a stable order:

```text
ADD → MULTIPLY → CLAMP → OVERRIDE → PROC
```

Within a phase, sort by explicit priority and source ID. This makes combinations debuggable and keeps seed outcomes stable.

### Save files

- `profile_vN`: unlocks, cosmetics, run history, achievements.
- `settings`: controls, display, audio, and accessibility.
- `suspend_vN`: optional single-run resume snapshot.

Write atomically, retain one backup, and include a schema version and checksum. A suspend snapshot records the run descriptor, tick, player build, RNG stream states or counters, director state, generated chunk IDs, and essential live entities.

### Performance budgets

Create a stress arena during the first milestone. A provisional vertical-slice target is:

- 1,000 active enemies;
- 600 projectiles or process effects;
- 400 pickups before merge rules;
- one boss;
- full HUD, audio, and CRT presentation;
- stable 60 FPS on the chosen minimum-spec machine, with no spawn-burst frame above 33 ms.

Use pools and preallocation, merge distant data pickups, cap particles/floating text/audio voices, batch compatible visuals, and prewarm worst-case process combinations. Profile before adopting a third-party ECS or native extension.

---

## 12. Scope ladder

### Mechanics prototype

- one chassis;
- movement, shield, hull, heat, and `VENT`;
- two processes and four behavior patches;
- `BIT`, `VECTOR`, and `SENTRY`;
- one rectangular graybox arena;
- XP, level-up cards, death, and restart;
- stress mode with placeholder glyphs.

**Gate:** ten consecutive unprogressed runs are enjoyable enough to replay without unlock rewards.

### Vertical slice

Build one polished 12-minute seeded run:

- one chassis;
- four processes;
- twelve patch definitions and two compile outcomes;
- five normal contacts, one elite protocol, one three-phase boss;
- one biome with eight authored chunk templates, three landmarks, and two hazards;
- deterministic layout, wave deck, offers, and seed copy/entry;
- terminal HUD, menus, log, compile sequence, victory, death, and run summary;
- six horizontal unlocks;
- suspend/resume;
- baseline accessibility toggles;
- automated seed, schema, combination, save, and performance tests.

**Gate:** players voluntarily replay the same seed to try a different build or route before more content is added.

### Version 1.0 content target

- four chassis;
- eight processes;
- sixteen to eighteen patches with at least 48 supported pairings;
- twelve major compile outcomes;
- ten standard enemy roles and four elite protocols;
- five gate/final bosses with compatible protocol variants;
- six biome families, five anomaly types, and a meaningful authored chunk deck;
- standard, daily, and threat modes;
- 30–40 horizontal and cosmetic unlocks;
- seed archive, run history, codex, achievements, and complete accessibility options.

Do not commit to 1.0 quantities until the vertical slice proves the upgrade grammar and run structure.

---

## 13. Production milestones

Planning assumption: one experienced gameplay developer with part-time art and audio support. Ranges are working estimates and should be recalculated after the mechanics prototype.

| Milestone | Deliverable | Exit gate | Rough effort |
|---|---|---|---|
| M0 — Foundation | Input, movement, swarm benchmark, content IDs, seed service | Stable stress arena and reproducible test stream | 1 week |
| M1 — Combat prototype | Two processes, heat/`VENT`, three enemies, XP and upgrade UI | Core loop is fun without meta progression | 2–3 weeks |
| M2 — Compiler | Patch operation pipeline, twelve supported combinations, one compile | Builds visibly diverge by minute six | 2–3 weeks |
| M3 — Seeded sector | Chunk assembly, validator, landmarks, wave cards, run manifest | 10,000 fuzzed seeds produce no invalid arena | 2 weeks |
| M4 — Vertical slice | 12-minute run, boss, terminal presentation, saves, accessibility | External players replay voluntarily | 3–4 weeks |
| M5 — Content alpha | Target chassis, processes, enemies, biomes, bosses, progression | All intended runs completable; content lock | 10–16 weeks |
| M6 — Beta / release | Balance, performance, migration, hardware, localization, recovery | Crash-free soak and release checklist pass | 6–10 weeks |

This suggests roughly 8–12 weeks to a credible internal slice, 14–18 weeks to a public-quality demo, and 6–9 months to a focused 1.0. Content ambition, custom art, platform work, and team experience can move those estimates substantially.

### Recommended implementation order

1. Movement, collision grace, shield, heat, and `VENT` feel.
2. Pooled `BIT` swarm and the worst-case performance arena.
3. `MASS_DRIVER` and `ARC.EXE`, including target bias.
4. Data pickup, level curve, and three-card pause.
5. Patch hooks: `ON_HIT`, `ON_KILL`, `ON_VENT`, `ON_COLLAPSE`.
6. Four patches that create visibly different geometry.
7. `VECTOR` and `SENTRY` telegraphs plus one wave card.
8. One compile branch with a visible behavior counter.
9. One three-phase boss with capped fodder.
10. Seed service, run descriptor, and a simple authored-chunk arena.
11. Terminal HUD and compile presentation.
12. Fuzz, soak, combination, save, controller, and accessibility tests.

Do not begin the full meta tree, six biomes, or large enemy roster before step 9 is fun.

---

## 14. Verification plan

### Automated checks

- Golden sequences for the project-owned PRNG and stable hash.
- Snapshot hashes for known sector seeds and wave schedules.
- Fuzz at least 10,000 seeds for unreachable landmarks, overlaps, invalid spawn points, and distribution outliers.
- Validate every stable ID, reference, prerequisite, exclusion, and tag.
- Prove every level-up state has at least one legal offer.
- Test patch ordering, proc caps, child recursion blocks, and all supported process-patch pairs.
- Run headless 30-minute bot soaks for leaks, NaNs, entity runaway, and director stalls.
- Test interrupted saves, corrupted profiles, backups, and every shipped migration.
- Record worst-case frame benchmarks in continuous integration.

### Playtest questions

- Can a first-time player explain `VENT` after one use?
- By minute six, can the player describe how their build changed?
- Are at least five distinct builds viable without one mandatory daemon?
- Does navigating toward a landmark create an interesting risk rather than busywork?
- Can players identify why they took damage or died?
- Do players choose routes based on build plans, not merely biome preference?
- Does retrying a seed invite a new strategy?
- Is every boss pattern readable with CRT effects enabled and disabled?

### Success criteria for the slice

- At least 70% of upgrades change behavior.
- Five supported build shapes can clear the slice within a reasonable balance band.
- Identical run signatures produce identical content snapshots.
- Zero invalid maps across the 10,000-seed test set.
- Stress target holds on the selected minimum-spec machine.
- All menus are usable by controller and at large UI scale.
- External testers voluntarily start another run without being prompted by unlock currency.

---

## 15. Major risks and countermeasures

| Risk | Countermeasure |
|---|---|
| Upgrade combinations explode | Cap slots, use tags and declarative operations, support a bounded pairing matrix, automate combination tests |
| Terminal effects hurt readability | Establish semantic colors and silhouettes first; make every CRT layer adjustable |
| Procedural sectors feel interchangeable | Use authored chunk decks, landmarks, hazard rules, and route reveals rather than noise-based geometry alone |
| Horde performance fails late | Build and keep the stress arena in M0; pool and batch from the start |
| Bosses become damage sponges | Use fixed health, movement tests, target-priority mechanics, and capped damage-independent objectives |
| Seed results drift between updates | Own and version the PRNG, isolate streams, store content hashes, and preserve published generator versions when needed |
| Adaptive upgrades feel arbitrary | Display counters before command phases and always offer a neutral branch |
| Meta progression hides a weak loop | Gate content production on repeat play without rewards |
| Space movement feels slippery | Make input immediate and keep inertia primarily visual; test gamepad response before adding content |
| Visual power obscures enemy tells | Give hostile telegraphs rendering priority and enforce effect/particle budgets |

---

## 16. Non-goals for the first release

- Online multiplayer or deterministic lockstep.
- Fully simulated orbital physics.
- Unbounded procedural weapon generation.
- Destructible terrain across entire sectors.
- A large narrative campaign with dialogue trees.
- Permanent power grind required to clear standard difficulty.
- Endless mode before the 20-minute run is balanced.
- More content as a substitute for proving the process-patch grammar.

---

## 17. The first playable test

The fastest proof of the concept is a graybox containing:

```text
COURIER chassis
MASS_DRIVER + ARC.EXE
FORK_ON_KILL + CONDUCTIVE_MARK + VENT_AMPLIFIER + OVERCLOCK_KERNEL
BIT + VECTOR + SENTRY
one six-minute wave script
one WATCHDOG phase
one visible compile counter
seeded upgrade offers
```

If this small build makes players want to retry the seed and pursue a different compile, the concept is working. If it does not, change the combat and upgrade grammar before building procedural biomes or meta progression.
