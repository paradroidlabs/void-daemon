# First Arrival / roughly twenty-minute playable chapter

Scope: the requested amount of fleshed-out campaign gameplay in the existing
Godot project. This is not a claim that the whole original GDD, full A-Life
ecosystem, music IDE, supplied soundtrack or sibling graphic novel is finished.

| Requirement | Authoritative evidence |
|---|---|
| Approximately twenty minutes of playable content | Four complete normal-input pilots: 19:30 Graviton, 19:58 Bastion, 19:48 Scrapper, 20:54 Redline; eleven objectives each, no failures, no reading time added. PLAYTIME_AUDIT.md and preserved full-route JSON. |
| A campaign rather than an isolated lab | chapter_catalog.gd contains eleven connected, distinct authored mission nodes. campaign_host.gd carries chassis, upgrades, hull, consequences and checkpoint progress through the actual game scene. campaign_test.gd completes every real mission condition through the host. |
| Substantive authored progression | Relay disruption, gravity interception, separated picket securing, solid-room archive retrieval, Watchdog, carrier rescue, seeded sector exploration, matched power routing, moving convoy protection, three-phase Warden, combat escape. These have physical objectives and explicit success/failure conditions, not minimum-duration waits. |
| Narrative setup, decisions and ending | Nine illustrated terminal-fiction pages in three hubs; one-time choices change actual escorts, hull, carrier toughness and convoy detail sizes. An authored First Arrival epilogue follows actual escape. story_test.gd verifies saved pages, costs, choices and deployed consequences. Fiction is original prototype material, not approved imported canon. |
| Reachable geometry and readable counters | Shared CombatGeometry solid/visibility/doorway rules; facility, expedition and tactical tests. Rendered desktop/portrait campaign and story fixtures inspected; paused map avoids obstructing combat. No full human usability certification is implied. |
| Existing chassis and input loop retained | All four complete campaigns use normal ship movement, aim, attack and maneuver intents, without mission-state/health/position writes. Existing native two-thumb, desktop/controller, inertia, kit, pause, zoom and scorecard regression fixtures remain in test_game.ps1. Actual hardware and human handling remain separate gates. |
| Retry/resume without silently skipping new content | ConfigFile disk roundtrip, stable-ID remapping, reward idempotency, failed-attempt separation, retained entry state and completed-draft migration tests. Old completed .1/.2 checkpoints advance to unplayed added content, not a falsely completed new ending. |
| Deliverable outside the editor | Versioned Windows .3 EXE, embedded resources, launchers, instructions, license notices, source fingerprints and executable hash. Packaged campaign entry and survival smoke both passed with exit 0 and no runtime error lines. Earlier builds are preserved. |

The full regression script rejects runtime errors even when Godot returns zero.
Editor user-directory / rendered shader-cache warnings and occasional headless
audio ObjectDB teardown warnings are separately recorded, not silently classified
as gameplay failures or performance evidence.

The four chassis timing probes run source in the installed Godot engine. An
additional `--main-pack <EXE>` run loaded the actual shipped compiled resources
and completed all eleven Graviton missions in 1170.10 seconds with no failures;
its raw evidence fingerprints .gdc resources. This verifies the embedded content,
not native-window human handling. A separate external-script probe launched on
the release PE did not initialize with usable output and was stopped; that is
not completion evidence. Native EXE campaign entry and survival smoke passed.

Remaining product work: human pacing/fun/fairness review, difficulty/replayability,
physical phone/controller validation, measured rendered FPS, supplied music
audition, canon curation and more ambitious ecology/narrative tooling. None is
represented as completed by a twenty-minute content prototype.
