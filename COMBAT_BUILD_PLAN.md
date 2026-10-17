# VOID//DAEMON — combat rebuild and playtest plan

Status: the first Graviton/Salvo example and visual scorecard are implemented. Mechanics, mouse-input flow, and native touch routing have automated checks; human fun and physical-device gates remain open. Later chassis milestones below are proposals.

The user selected the direct **Graviton Surge → charged salvo → ARC/driver follow-through** setup as the first build. The playable implementation uses M1 to gather and load, release to launch, and a separate Shift/Space escape. Gravity is part of the offensive kit. See [current playtest instructions](PLAYTEST_GRAVITON.md).

Companion design: [combat identity and red-team review](COMBAT_IDENTITY_RED_TEAM.md).

## Build strategy

Deliver small playable builds with explicit decisions between them. Prove a complete first kit, then prove a combination, then prove a contrasting kit. Develop mouse/keyboard, controller intent, and touch input alongside each interaction. Actual device testing is required before claiming a device is supported.

The first target is the Graviton kit: an offensive gathering field and charged missile rack, Phase Skip as a separate escape, and the existing automatic processes. The second target is Bastion: continuous beam and Breach Step. Additional chassis remain later candidates.

Keep the current demo available as a comparison throughout the experiment. Preserve the completed visual scorecard and its exact damage accounting. Do not raise the current 180-enemy cap while introducing these systems.

Stages below are reviewable builds, not calendar estimates. Measure the first kit's implementation and iteration time before estimating the remaining work.

## B0 — Baseline and a quick combat lab

**Question:** Can we compare changes without replaying five minutes or relying on memory?

Build tasks:

- Preserve the current working demo, including dirty/untracked source files needed to reproduce it. A clean tracked-file archive alone would omit current work. Record the engine version and baseline configuration; do not reset unrelated changes.
- Provide a clearly named baseline launcher and experimental combat-lab launcher. These are proposed deliverables; they do not exist yet.
- Add three short fixtures: a pursuing cluster, dispersed enemies with a ranged threat, and a boss firing lane. Each has fixed initial positions, health, and loadout.
- Let the tester restart the fixture and select its loadout quickly. Add a short control card that names the actual ability being tested.
- Record build identifier, fixture, input device, loadout, and tuning preset with each result.

Test tasks:

- Run existing smoke and damage/scorecard regressions.
- Confirm the baseline launcher reproduces the baseline and the lab cannot accidentally affect normal run state.
- Play each fixture once to identify whether it exposes its intended question. A seed alone does not guarantee identical combat after different player actions.

**Exit:** a tester can enter a comparison, play it, and retry promptly without waiting for progression or random drops. The baseline remains available.

**If it fails:** simplify the lab. Do not build a general scenario editor or a telemetry service.

## B1 — One complete Graviton/Salvo kit

**Question:** Is Unleash satisfying before it has a combo upgrade?

Build tasks, in dependency order:

1. Add device-independent action intents: Unleash begin/aim/release/cancel, maneuver, and pause. Keep classic-mode bindings isolated from experimental bindings.
2. Implement the offensive field and missile attack together: real bounded pull during the hold, useful tap, partial rack, full rack, target allocation, staggered launch, bounded retarget, splash, and reload.
3. Implement Phase Skip using a shared endpoint check for bounds and terrain. Shift and Space are aliases for one action and one cooldown; pressing both cannot grant two skips.
4. Add the attack's ship animation and sound at the same time: racks open, cells load, readiness is apparent, launch has recoil, missiles travel and impact visibly, racks recover.
5. Establish the experimental heat model. Full VENT is absent in this mode; cooling and active costs must support repeated combat. The classic mode retains its existing rules.
6. Add current ability names, readiness, and heat cues to the HUD. Extend the scorecard with real Unleash and maneuver counters and damage attribution.

Experimental control contract:

| Role | Keyboard / mouse | Controller | Touch |
|---|---|---|---|
| Move | WASD / arrows | Left stick | Left thumb stick |
| Aim / allocate | Mouse direction | Right stick | Right action-pad drag |
| Unleash | M1 | Right trigger | Hold/release action pad |
| Maneuver | Shift or Space | Right shoulder | Maneuver button; slide-to-maneuver while holding attack |
| Pause | Esc / P | Start | Pause control |

M2/Q remains unassigned in the experiment until a separate setup action is justified. The control card must say that clearly. Regenerating shield remains passive.

Cancellation contract:

- Maneuver takes priority over an uncommitted charge or a live channel.
- Canceling a charge does not fire it. A committed salvo finishes its launch sequence independently while the ship moves; death ends further player launches.
- Spent heat is not refunded. A charge that has not committed payload cannot secretly spend or refund that payload.
- Pause, upgrade selection, focus loss, and end-of-run clear held input. Returning requires deliberate re-arming.
- Touch sliding into maneuver must produce cancel then maneuver, never release-to-fire then maneuver.

Test tasks:

- Automate high-impact correctness checks: direct/splash damage de-duplication, target death during arming and flight, one-time heat reservation, no extra charge from input aliases, and no attack surviving a menu/focus transition.
- Test zero targets, full heat, rapid tapping, repeated canceling, arena edges, and death mid-salvo.
- Perform a mouse/keyboard play pass and touch-control pass now. Validate controller mappings on actual hardware when available; synthetic events alone are insufficient.
- Play unupgraded tap/partial/full attacks against the fixtures. Ask what happened during the hold and why the tester chose to release.

**Exit:** the attack is useful alone, loading and readiness are recognizable, partial releases have a purpose, and escape is reliable while attacking. Input and damage defects are fixed before expansion.

**If it fails:** revise charge duration, allocation, impact, or attack geometry. Stronger upgrades are not a remedy for a weak base kit. Use the salvo-only lab condition to diagnose the field's contribution. After two focused revisions, compare a simpler direct-fire variant.

## B2 — The first emergent combination

**Question:** Do players deliberately create and exploit an opening?

Build tasks:

- Use the kit's offensive field to set up the salvo; Phase Skip remains a separate escape. The field is available at baseline rather than gated behind a mobility patch.
- Apply field forces as a persistent contribution after normal enemy steering. Start with one field per player and a small affected-enemy cap. Explicitly handle resistance during committed charger attacks and boss behavior.
- Make the field last long enough for an observable choice, missile arming, and travel. Determine this from actual timing rather than matching a duration in a document.
- Offer three fixed lab conditions: salvo-only ablation, the complete Graviton/Salvo base kit, and the kit with selected existing ARC/driver patches. The ablation is a diagnostic preset, not an additional promised chassis. Keep weapon and enemy tuning stable across that comparison.
- Preserve existing source rules. FORK_ON_KILL remains a MASS_DRIVER effect unless deliberately extended and re-described.

Test tasks:

- Check that enemies physically group, splash affects the resulting geometry, and ARC reaches targets through its actual chain rules.
- Test overlapping effects, disappearing targets, field expiration, world boundaries, and control against a boss or committed charger.
- Play the same fixtures in a different order across testers to reduce practice bias.
- Watch whether players release early, skip the gravity setup, or reserve escape for an incoming attack.

**Exit:** testers can explain a combination they used, and the fixtures produce at least two useful action sequences. Grouping improves coverage through actual spatial consequences. Baseline attacks remain useful without the patch.

**If it fails:** distinguish the cause. Weak feedback needs feedback work; a compulsory sequence needs different spatial tradeoffs; resentment about spending escape needs a control-role experiment.

### B2 decision branch — Does setup need its own button?

The implemented hold/release sequence already separates offense from escape. If playtesting shows a need to separate gathering from salvo commitment, compare a dedicated M2/Q gravitational setup while keeping M1 for Unleash and Shift/Space for escape. This is an explicit three-action experiment, not an automatic scope increase.

Test whether players make better decisions and whether touch remains usable. A third action needs a workable two-thumb interaction or an alternative activation scheme; adding a third small button is not validation.

Choose between the two-action and three-action models using play evidence before multiplying chassis kits around that decision.

## B3 — A contrasting Bastion kit

**Question:** Does choosing a chassis change the decisions a player makes?

Build tasks:

- Implement a real continuous SIEGE_LANCE beam: short ignition, fixed-step contact damage, heat expenditure, contact feedback, release, and immediate defensive cancellation.
- Add BREACH_STEP: short predictable displacement with declared protection and a frontal shove or barrier. Preserve the same input role as Courier's maneuver.
- Add a distinctive silhouette, firing transformation, and sustained sound. Reserve a voice for the channel so normal shots cannot steal its audio loop.
- Initially keep the automatic processes shared with Graviton to isolate manual-kit differences. Chassis-specific starter processes follow after this comparison.
- Add beam contact time, channel duration, and source damage to the scorecard without dropping existing metrics or introducing scrolling.

Test tasks:

- Check equivalent damage and heat under different rendering frame rates at the same simulation settings.
- Test rapid beam toggling, contact jitter, sustained empty-space fire, multiple overlapping targets, and cancel during ignition/channel.
- Compare the same fixtures on Graviton and Bastion. Observe positioning, commitment, escape use, and partial release/contact choices.

**Exit:** players describe different reasons to hold and stop M1, and visibly alter positioning between the two ships. The beam does not simply outperform missiles in every fixture.

**If it fails:** change range, coverage, aim behavior, or commitment. Avoid assigning a different color and a damage penalty as the entire distinction.

## B4 — A small, deliberate upgrade matrix

**Question:** Do upgrades change how the surviving kits combine their actions?

Build tasks:

- Add at most one alternative attack form per surviving chassis and a small set of supported effects. Start with no more than three new effect choices beyond the baseline Graviton field.
- Declare compatibility and exclusions. Offer only implemented, meaningful choices; describe replacements and downsides accurately.
- Introduce root activation identity and bounded descendants before allowing new effects to spawn effects. Define continuous-hit intervals separately from render frames.
- Deliberately migrate relevant VENT cards for the experimental mode. Do not silently turn GROUND_LOOP into unrestricted mobility refunds.
- Test existing automatic-process patches as well as new active effects. Give source damage one owner and avoid double-counting combo participation.

Test tasks:

- Check legal offers, exclusions, source attribution, resource refunds, child caps, and cooldown floors where applicable.
- Play a few authored loadouts that exercise different sequences: concentrated fire, gravity/area coverage, and automatic-process continuation.
- Stress the dense configuration with gravity, missile area hits or beam contact, ARC fanout, forks, returns, hostile shots, and the boss.
- Profile frame-time spikes and effect counts at the current enemy cap on the target hardware. Desktop results do not establish phone performance.

**Exit:** at least one form choice and one effect choice alter a recognizable decision, all offered cards work, and no combination produces unbounded recursion or perpetual escape.

**If it fails:** remove or restrict the offending interaction. Do not add content while the small matrix is still unclear.

## B5 — Put the surviving system into the run

**Question:** Do combinations stay interesting as enemies and upgrades accumulate?

Build tasks:

- Integrate the selected controls, two kits, and curated upgrade pool into the existing five-minute survival and boss structure.
- Add a minimal chassis selection with an accurate kit preview and matching control legend.
- Differentiate starter automatic processes and passive/resource traits incrementally. Compare the manual-only chassis distinction before and after this addition so its effect can be understood.
- Update gameplay HUD, upgrade text, help, and scorecard together. Use the current no-scroll scorecard; compact views retain fixed tabs.
- Identify the build and ruleset used in testing. Reproduce content offers without promising bit-identical combat replays.

Test tasks:

- Run the existing smoke/report suite plus the new input/ability/interaction checks.
- Play complete runs, including early death, zero kills, boss death, maximum installed patches, restart, pause, and viewport changes.
- Check both attack-first and automatic-process-focused builds. High manual damage is acceptable; automatic upgrade choices still need to matter.
- Check long-session comfort, visual readability, reduced effects, target retention, and actual device controls.

**Exit:** players voluntarily retry to explore another sequence or build. Late-run play remains readable, automatic systems remain relevant, and technical failures do not interrupt the run. Replaying the same seed is optional.

## B6 — Expand only from evidence

Choose the next chassis from the remaining unserved decision space. Scrapper's gravity manipulation is the likely third experiment. Redline's positional recall comes after endpoint validation and resource ownership are dependable.

A complete chassis eventually has distinct baseline weapons, Unleash, maneuver, passive/resource interaction, silhouette, and sound. Shared input roles and upgrade rules remain consistent. Not every underlying implementation or upgrade needs to be unique.

Position recall requires extra checks: short history, invalid historical position, current-world collision, level transitions, pause/reset, death, and proof that health/heat/cooldowns/projectiles are not restored. Full world rewind remains a separate proposal.

Additional environments, enemies, meta progression, adaptive compilation, a broad content catalogue, and commercial planning are outside this combat experiment.

## Verification cadence

Use three levels of evidence:

| When | Check | What it can establish |
|---|---|---|
| After relevant code changes | Parse/smoke, damage/report regressions, focused mechanics checks | Correct accounting, legal transitions, bounded effects, no obvious integration regressions |
| Each playable increment | Short hands-on fixtures on available devices | Responsiveness, readiness, aim/cancel behavior, readable feedback |
| At a design gate | Several fresh players trying alternate conditions | Repeated misunderstandings, differing decisions, reasons to replay |

Do not automate a claim that an attack feels powerful or that a combo is fun. Do not treat a small formative group as a statistically representative result. Engineering failures such as a stuck attack or duplicated damage block expansion; subjective findings guide the next focused revision.

Use a lightweight local record per test build, proposed under `artifacts/playtests/<build-id>/`: configuration, observations, decision, and a short capture if useful. Record only useful facts such as release level, cancel count, contact time, damage sources, heat stops, and the fixture played. No backend is needed.

A test note should answer: what changed, what was held constant, what happened, what we learned, and the one adjustment to try next. Keep each balance experiment focused; implementation fixes can be grouped where they do not undermine the comparison.

## Completion contract for every build

Before calling an increment ready to play:

- Provide a launchable build or launcher and a short statement of the change to evaluate.
- Display accurate controls and ability names for the selected mode/chassis.
- Complete the relevant automated checks and an actual hands-on pass; identify any device not yet physically tested.
- Keep the comparison build available and record the version/configuration tested.
- State the gate result: advance, revise one identified issue, or remove the mechanic.

The current handoff implements **B0 + B1 + the initial B2 combination**: preserved baseline sources, quick fixtures, direct Graviton/Salvo offense, independent phase escape, input paths, and scorecard reporting. Review the actual playable kit before advancing to another chassis. Automated correctness is recorded separately from the still-open human design gates.
