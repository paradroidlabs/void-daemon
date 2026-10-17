# VOID//DAEMON — Unleash, chassis abilities, and emergent combos

Design review and prototype brief • 2026-10-16

Status: proposed experiments, not implemented mechanics. This review changes no gameplay code. All timings, caps, and numerical targets below are starting hypotheses for the demo.

Current implementation note: the user subsequently selected **Graviton Surge → charged salvo → ARC/driver follow-through** as the first kit. M1 directly owns gathering and the salvo; Shift/Space is a separate escape. The earlier Courier/gravity-wake sketches below are retained as design history. [Current playable setup](PLAYTEST_GRAVITON.md) and [updated build plan](COMBAT_BUILD_PLAN.md) describe the implemented version.

## 1. Decision

Pursue an active combat layer built around **setup, commitment, payoff, and escape**. Each chassis gets a distinctive Unleash on M1 and a distinctive displacement ability on Shift. Automatic weapon processes remain active and become additional links in a sequence the player starts.

The strongest first experiment is **Graviton Surge → charged missile salvo → automatic weapon cleanup**, with a real sustained beam as the second contrasting experiment. Full rewind and a complete four-chassis roster come later, only if those experiments earn further work.

The important ambition is that a player can invent a sequence because they understand what the systems do. Gravity moves enemies together; nearby enemies share missile splash; clustered survivors become good ARC targets; a piercing killing hit can fork. Those are independently useful rules that can combine. A special check saying “gravity followed by missiles deals 200% damage” would demonstrate an authored recipe, not this kind of emergence.

Borrow fighting games' commitment, spacing, hit confirmation, cancel opportunities, and recovery. Keep command entry simple enough for touch. The skill should be recognizing and creating an opening, then choosing what to do with it.

Success sounds like: “I pulled the chargers together, fired half a rack before the laser arrived, then crossed the lane so my return rounds finished them.” Failure sounds like: “I hold until full, press Shift whenever it lights up, and repeat.”

## 2. Evidence and limits of this review

The user's observation is the starting evidence: charging, holding, and unleashing felt dead. This review addresses that attack feedback and decision problem. The earlier movement-focused response misread it.

The checked-out project currently exposes automatic MASS_DRIVER and ARC.EXE plus VENT; its input code does not contain the reported M1 Unleash or Shift implementation. Consequently, this document does not claim to diagnose that particular implementation or its timing. It proposes a replacement interaction design and identifies integration constraints in the source available here.

Relevant current behavior:

| Existing system | Verified behavior | Consequence for this proposal |
|---|---|---|
| MASS_DRIVER | Piercing projectile; candidate targets scored partly by how many enemies line up | Enemy grouping and player alignment already have potential value |
| FORK_ON_KILL | Applies to original MASS_DRIVER killing hits; children cannot fork again | Missile kills will not automatically inherit this patch |
| RETURN_VECTOR | Original driver rounds that expire by lifetime can return toward the ship's position at expiry | Repositioning before expiry can change the return line; early collision expiry does not create a return |
| ARC.EXE | Nearby chains with range and per-jump falloff | Compression can improve actual chain reach without an artificial combo bonus |
| CONDUCTIVE_MARK | Extends chains and favors a surviving marked endpoint as the next starting target | There is already a small amount of persistent target state to build around |
| ARC_FANOUT / GROUND_LOOP | Extra branches; completed chains refund VENT cooldown | Moving refunds to Shift without limits could create an escape loop |
| Reactor | 100 heat, 13 cooling/s, normal processes soft-throttle above 92% | A new active attack needs a deliberate heat budget |
| VENT | Full heat dump, brief protection, damage/knockback pulse | Splitting or replacing its jobs changes several existing upgrades |
| Enemies | Their role logic writes velocity during updates | Persistent gravitational force needs its own movement contribution; a one-time velocity assignment is insufficient |
| Rendering / sound | Vector drawing and short synthesized cues | A charge sequence, sustained beam, and looped audio require new states, not just larger existing effects |
| Arena | Current normal-enemy cap is 180 | Keep this cap while testing ability interactions and worst-case clusters |

Source anchors: [input and orchestration](src/main.gd), [ship and reactor](src/actors/player_ship.gd), [weapons and existing interactions](src/systems/weapon_controller.gd), [upgrade descriptions](src/systems/upgrade_catalog.gd), [enemy movement](src/actors/enemy.gd), [projectile lifecycle](src/actors/projectile.gd), [audio](src/audio/synth_audio.gd).

The original [game plan](GAME_PLAN.md) promises movement plus one action. Adding both Unleash and a distinct Shift is a real change to that control budget. This proposal accepts movement plus two actions for the experiment and requires testing the resulting attention and touch burden. It does not silently assume the old promise still holds.

## 3. What to take from Hades

Use action roles rather than literal Q/M2 bindings, which vary by configuration. The useful reference is the relationship among a weapon's primary action, its special, positioning, and upgrades.

Supergiant's own patch notes document substantial changes to weapon actions: charged specials, a clustered bomb spread, and replacement attacks. They also show boss-specific value for knock-away effects. This supports testing changes to geometry and timing, and giving control-focused builds a useful boss interaction. It does not prove those exact choices will work in VOID//DAEMON. [Hades: Long Winter update](https://www.supergiantgames.com/blog/hades-long-winter-update-patch-notes/)

The developer also used explicit compatibility exclusions between upgrades. That is a useful precedent for curating combinations instead of promising that every modifier works with every weapon. [Hades: Big Bad update](https://www.supergiantgames.com/blog/hades-big-bad-update-patch-notes/)

Charge-dependent sound pitch, movement integrated into an attack, and fixes to input buffering appear in the official updates. My design inference is that the continuity of input, animation, movement, and sound deserves as much attention as the final damage event. [Hades updates](https://www.supergiantgames.com/blog/hades-updates/)

For this game, separate three design layers:

1. **Chassis:** the baseline handling, silhouette, Unleash behavior, and Shift behavior.
2. **Form-changing patches:** alter delivery, such as salvo versus torpedo, beam versus pulse, or blink versus anchor return. Replacements are shown explicitly.
3. **Effect patches:** attach a bounded consequence to a supported event, such as a conductive hit, a gravity wake, or an exposed target.

Keep PROCESS, PATCH, and DAEMON as the game's vocabulary. These layers are authoring categories, not an excuse to add several more currencies or upgrade screens. One form replacement per action is enough for the first experiment. A replacement must remain legible after it receives an effect patch.

## 4. Combat grammar: the fighting-game interpretation

An action needs more than a charge percentage. It needs a role in a sequence.

| Role | Player decision | Example in this game | Failure to watch for |
|---|---|---|---|
| Setup | Where should the next opening exist? | Pull enemies into a small field; mark a threatening elite | Setup becomes compulsory before every attack |
| Commitment | How much time, heat, or positioning do I invest? | Load more missiles; keep a beam on one target | Waiting longer is always the correct answer |
| Confirmation | Did the situation become favorable? | Several targets enter the field; a beam establishes contact | Important information exists only in a meter |
| Payoff | Which attack exploits that opening? | Release a partial salvo into a cluster; sweep across an aligned row | Big effects conceal negligible impact |
| Cancel | Is survival worth abandoning the attack? | Shift out of the beam or abandon a half-loaded salvo | Defensive input is ignored until an animation finishes |
| Recovery | What can I do while this weapon settles? | Reposition to line up MASS_DRIVER and returning rounds | Player waits with no useful action |

No quarter-circle commands, memorized button strings, mandatory perfect-release timing, or combo score decay in the first version. Give input buffering a forgiving starting range around 100–150 ms, but never buffer an attack through a pause menu, focus loss, death, or a defensive cancel.

A combo is an observable chain of consequences, not necessarily an uninterrupted animation. The player's automatic weapons are allowed to contribute. That is how this can remain a survivors-like while gaining deliberate combat expression.

### The shared rules that create emergence

Start with spatial facts already meaningful to combat: position, proximity, line of fire, projectile travel, and remaining health. Add only one or two explicit statuses after spatial combinations work. Every persistent status needs one clear rule, a duration or limit, and a readable cue.

Avoid introducing a dozen bespoke states just to make a combo diagram look sophisticated. “Grouped” can simply mean enemies actually occupy a smaller area. There is no need for a GROUPED damage multiplier.

For effects that spawn other effects, track the original activation and bounded descendants. The base mechanics can combine broadly while recursive spawning remains tightly controlled.

### Example: Graviton Surge → charged salvo

Proposed Courier loadout: missile Unleash, Phase Skip, and a GRAVITON_WAKE Shift patch.

1. The player moves past a pursuing group and uses Shift to cross a short distance. A small gravitational field remains at the departure point, safely behind the ship.
2. The field begins pulling nearby ordinary enemies immediately. Its duration must allow a readable choice, charge, and missile travel; start around two seconds and measure actual arrival times.
3. Holding M1 opens the missile racks and allocates a growing number of missiles across the indicated targets. The player can fire early if a new threat arrives.
4. Releasing launches a staggered salvo. Splash overlaps because enemies are physically close. The field does not multiply damage simply because the weapon is a missile.
5. ARC can connect survivors that would otherwise be out of chain range. A subsequent MASS_DRIVER killing hit can fork, using the existing restriction on its source.
6. The player moves to alter the line taken by future return rounds. This is conditional on original rounds surviving until their lifetime expires, not guaranteed after every shot.

There are alternate decisions: fire early to interrupt an approach, save Shift for the incoming boss lane, skip the setup against a scattered formation, or aim the salvo at an ungroupable boss while the automatic processes clear its adds.

The critical test is whether those alternatives actually occur. If every encounter rewards steps 1–6 in the same order, the system has become a rotation.

### Other combinations to test later

| Sequence | Why it could work | What must remain true |
|---|---|---|
| Gravity field → piercing beam | Compression creates a line or compact crossing that a continuous beam can exploit | A circular cluster is not automatically a perfect line; positioning must matter |
| Beam contact → exposed target → automatic driver | A sustained attack opens a brief opportunity for another process | Exposure must not merely buff the beam itself into mandatory permanent uptime |
| Salvo → Shift across a lane → return rounds | The player can relocate while the independent projectiles resolve | Shift cannot duplicate missiles or refund already spent heat |
| Gravity release → ARC fanout | Field gathers enemies into valid chain distances | Displacement cannot cancel every enemy tell or disable boss mechanics |
| Hot Unleash → positional recall → return fire | Repositioning lets an aggressive player leave a dangerous firing location | Recalling position must not restore resources or erase incoming world state |

These are proposed combinations. Only the automatic process behaviors listed in section 2 exist in this checkout.

## 5. Candidate chassis kits

These four kits define different decisions, not a commitment to build four complete classes now.

| Chassis | M1 Unleash | Shift | Core combat rhythm | Main risk |
|---|---|---|---|---|
| COURIER | **SWARM_RACK:** aim and load a missile salvo, release to launch | **PHASE_SKIP:** short directional teleport | Allocate, release, relocate while the salvo resolves | Homing removes aim decisions; missiles waste themselves on dead targets |
| BASTION | **SIEGE_LANCE:** brief ignition followed by a real sustained rail beam | **BREACH_STEP:** short protected displacement with a frontal shove | Establish a firing lane, maintain contact, break out of commitment | Hold-to-win sweeping; beam effects obscure incoming fire |
| SCRAPPER | **GRAVITY_CLAMP:** sustained external field, release to collapse | **TOW_STEP:** short displacement leaving a decoy that briefly attracts ordinary pursuers | Gather, redirect, collapse, let processes exploit proximity | Permanent crowd control; a pile of enemies gets dragged onto the player |
| REDLINE | **CORONA_DRIVE:** short-range pulsing plasma stream that strengthens with heat | **BACKTRACE:** return to a visible recent position | Enter a dangerous range, spend heat, leave via a planned position | Free resource rewind; history destination becomes an unreadable trap |

Base M1 behavior stays tied to the chassis. Shared effect patches allow cross-family interactions such as a gravity setup on Courier. This avoids a hard divide where only the gravity ship can ever use gravity, while preserving recognizable base kits.

### Courier: a missile salvo with a physical loading process

On press, two side racks open and one missile becomes available promptly. During the hold, additional cells light and the targeting display shows allocation. Start with six missiles and roughly 0.8 seconds to a full rack. A tap should still produce a useful single shot.

While holding, the player makes a targeting decision: concentrate on one durable target or sweep a cone to spread the rack across a group. Use stable target retention and show allocation with brackets and a small count. Avoid a target roulette that reassigns the whole rack every frame.

On release, fire in a short stagger, roughly 60–80 ms between missiles. Alternate launch tubes; show recoil at each tube; give the salvo a distinct launch rhythm and impact rhythm. Separate launch, travel, and detonation so the payload reads as a machine doing work.

Use a reload after each committed salvo so rapid taps cannot bypass the rack's intended cadence. Keep a partial salvo useful for an immediate threat even if a full rack is more efficient. Once a salvo is committed, its short launch sequence resolves independently while the player moves or Shifts; defensive cancellation applies to uncommitted arming and live channels. Death still stops further player launches.

Each missile has a small blast radius. Direct hit and blast do not accidentally deal the full damage twice to the same target. Define and test the combined damage explicitly. Budget the salvo against actual early enemy health so its baseline visibly affects a group without requiring a rare upgrade.

The fully loaded hold remains useful for aiming and choosing release time. It does not keep granting unbounded damage. It shows an unmistakable ready state, with a quiet sustained audio cue rather than an endless rising pitch. Holding forever produces no launches; an optional accessible auto-release mode uses the same payload and reload rules.

Target death rules matter. Before launch, redistribute remaining slots within the selected cone. After launch, allow a bounded retarget inside a narrow forward region or continue toward the last known position and detonate there. Never let a missile spin around the player indefinitely, acquire a distant enemy across the arena, or vanish silently. Missile flight has a hard lifetime.

Candidate form variants, later: fewer heavy torpedoes with larger blast; broad dumb-fire saturation; a lower-damage pursuit rack. Each should change allocation or movement decisions. They cannot all stack.

### Bastion: an actual sustained rail beam

Holding M1 starts an ignition around 0.15–0.25 seconds, then a continuous damaging beam while the button remains held. Releasing stops it. This is a channelled weapon; forcing it into the missiles' release-to-fire contract would recreate the dead hold.

The ship separates its forward rails, braces side engines, and drives a bright narrow core from the muzzle. The beam must visibly connect to the contact point and react when it strikes an enemy. Width, impact geometry, and an audible load change communicate contact even when bloom is disabled.

Aim is responsive, but test a modest angular slew limit and reduced movement during firing. Never impose both a long charge and almost no movement as the first version. A narrow sweep that requires lining up targets creates a choice; a slow cursor that feels disconnected creates frustration.

Damage is integrated in fixed simulation steps, independent of display frame rate. Visual particles do not deal damage. A beam can pierce a bounded number of targets, with an explicit rule for whether targets behind the first receive falloff. Continuous contact may build pressure, but losing contact should have a small grace interval so tiny collision jitter does not reset everything.

Shift immediately ends the beam and moves the ship. The base beam cannot remain attached to a teleporting muzzle and sweep an entire arena for free. An afterimage beam could be a later form patch, with a fixed origin, short duration, and separate damage budget.

Suggested variants: a wider cutter with lower reach; a shorter, stronger pulse; a split beam with lower per-ray damage. Keep the first prototype to one continuous beam and one contrasting form.

### Scrapper: gravity that manipulates the fight during the hold

Press creates a visible focal point at a clamped distance from the ship. Holding pulls enemies toward it immediately, with a limited movement rate for the focal point. The hold has an ongoing mechanical result; the user is not watching a bar before gravity starts.

Keep the focal point outside the ship's contact radius. A gravity tool that consistently delivers enemies into the player's hull is an attractive visual attached to a broken interaction.

The field's ring compresses, debris orbits, and an intake silhouette on the ship widens. Release collapses the field for bounded area damage. Damage has a useful baseline even when little mass was gathered. More captured bodies may improve the payoff up to a cap; it must not be worthless against a lone boss.

Start with one field and a modest affected-enemy cap, such as twelve. Add force after normal movement decisions, limit acceleration and displacement, and apply role-specific resistance. Committed charger attacks should visibly resist rather than being permanently suspended.

A boss can resist displacement while accumulating bounded pressure that produces collapse damage. Display that alternate response. “The core mechanic does nothing to bosses” is unacceptable; so is dragging the boss out of every telegraph.

Projectile capture is a later explicit upgrade. Base gravity does not also provide unlimited bullet deletion, crowd control, invulnerability, and burst damage.

### Redline: retain the fantasy, defer the time mechanics

The attack should be a close-range, visibly segmented plasma stream, not a recolored Bastion beam. Its tactical question is whether to remain near danger for another pulse as heat rises. Ship apertures open, pulses tighten, and heat appears on specific hull structures.

BACKTRACE is position recall, not a world rewind. Start with a visible position marker about 1–1.5 seconds behind the ship, bounded by a maximum displacement. Shift returns to a valid current-space endpoint near that historical position.

Do not restore health, shield, heat, cooldowns, XP, enemies, projectiles, charges, or upgrade state. Do not resurrect killed enemies or roll back their loot. It cannot trigger automatically after death. Its short transition protection follows the same declared damage rules as other Shift abilities.

The past position can be dangerous now. Show it before activation. Validate terrain and arena bounds, not an invisible guarantee that the destination is tactically safe. If history is insufficient, use a clearly indicated ordinary escape fallback. If terrain blocks the recall, clamp it predictably and preview the actual endpoint.

This can be excellent, but it adds memory, preview, invalid-endpoint, pause, and reset cases. It is the last kit to prototype, not the foundational escape mechanic.

## 6. Shift must stay dependable as it becomes expressive

All Shift variants have a shared input promise: immediate defensive priority, predictable destination, a readable cooldown, and availability independent of attack heat. Directional variants follow movement intent; when stationary, use the last movement direction with a visible preview. Do not suddenly teleport toward an auto-target.

Teleport crosses a short gap through enemies. Solid terrain still constrains the result using a common safe-endpoint rule. Breach Step traverses a short path with declared protection and moves enemies aside, but does not freely tunnel through walls. Neither grants damage immunity for its entire cooldown.

Tow Step should work without a previously deployed gravity field. A later anchor-swap variant can depend on a placed object, but it needs an explicit ordinary escape fallback. A survival button that goes dead because the setup target died is unacceptable.

For the first implementation, Shift cancels an active charge or channel immediately. It never releases an armed salvo as a side effect of canceling. Already launched missiles keep traveling and already spent heat stays spent. A fresh attack input is required after the cancel. Keep initial charge times short enough that abandoning one does not feel like losing several seconds of work.

A later CHARGE_RELAY form can preserve a bounded armed payload across one Shift. It must carry the same activation identity and never duplicate ammunition or refund a launched shot. This is an intentional cancel upgrade, not an undocumented baseline loophole.

### What happens to VENT?

The preferred two-action experiment replaces the standalone VENT input with Shift and redistributes VENT's functions deliberately. Shift provides escape. Passive cooling provides baseline reactor recovery. Optional Shift patches add a bounded cooling or pulse effect. Do not automatically give every Shift full heat removal, a damaging explosion, protection, and movement; that would make using it on cooldown too attractive.

This requires a prototype variant or a clear migration, not silently repointing current upgrade IDs. GROUND_LOOP cannot become unrestricted Shift refunds. VENT_COOLANT cannot retain text about nonexistent retained heat. VENT_AMPLIFIER and OVERCLOCK_KERNEL's high-heat pulse need explicit replacement descriptions and behavior if offered in the new mode.

An alternative is to keep VENT as a third active action. Reject that for the first touch-inclusive test: it creates an extra simultaneous control demand before the two-button loop has proved itself. Do not remove the existing baseline mode while comparing.

There is another legitimate future branch: a dedicated setup action on M2/Q, Unleash on M1, and escape on Shift. If the two-action test makes players resent spending their escape just to create a gravity opening, that result challenges the combined input role, not the combo concept itself. Compare a dedicated setup slot before abandoning the idea. It would require a fresh touch design and an explicit increase in control scope; do not quietly add it to the first build.

### Reactor feasibility

At base rates with continuous valid targets, current auto processes request approximately `3.8 / 0.72 + 7.5 / 1.18 = 11.63` heat per second, against 13 cooling. That leaves only about 1.37 heat/s of net cooling before discrete timing and throttling. Removing full VENT without revisiting these values would make recovery from active attacks slow.

A candidate test is 22 passive cooling/s, roughly 30 heat for a full missile salvo, and roughly 45 heat/s during the continuous beam. These are experiments, not final balance. Under the same simplifying assumptions, the beam adds about 34.6 net heat/s and reaches 100 in about 2.9 seconds from cold. Real target availability, upgrades, warmup, and throttle change this result.

At the heat limit, the active weapon stops or cannot commit further payload. Ordinary processes retain their existing soft throttle. Give active fire a lower rearm threshold, for example 60, and require a fresh press; otherwise a held button can chatter between firing and overheating. Shift stays usable. Already committed missile launches must have their heat reserved once, avoiding a half-fired rack and ambiguous refunds.

The rack preview must distinguish loaded capacity from currently affordable payload if automatic fire changes available heat during a hold. Show unavailable cells clearly. At release, commit only the previewed affordable payload and reserve its cost atomically; each missile must not charge heat again when spawned. A fully blocked release needs a clear cooling cue, not a silent click. Test this specifically at the thermal boundary before relying on the shared heat model.

Measure whether the best strategy becomes Shift spam for cooling. If it does, reduce the cooling incentive or separate its recovery cadence from mobility. Preserve the escape decision.

## 7. Patches should connect actions without scripting the entire combo

For the first two-chassis comparison, author only a few supported combinations. Tag-based compatibility is useful, but a tag alone is not evidence that an interaction is balanced or even meaningful.

| Candidate patch | Actual rule | Combination opened | Limit / cost |
|---|---|---|---|
| GRAVITON_WAKE | Shift leaves a short pull field at departure | Escape creates a cluster for the next salvo or beam | One field per player; replaces the other Shift effect; bosses resist displacement |
| CONDUCTIVE_PAYLOAD | Supported direct hits apply a bounded conductive effect or a limited chain event | Manual aim can prepare contacts for ARC | Per-target interval plus a per-player proc budget; no recursive chains |
| CHARGE_RELAY | Retain the existing armed missile payload across one Shift | Charge → reposition → release | No added missiles, no repeated banking, no heat refund; later experiment |
| BREACH_TRACE | Sustained beam contact leaves a short exposure window for other sources | Beam opens an automatic-weapon follow-up | One non-stacking status; no self-amplification loop |
| COOLANT_WAKE | Shift dumps a limited amount of heat | Aggressive attack can transition into recovery | Competes with gravity wake; never grants full cooldown reset |
| AFTERIMAGE | A Shift leaves a brief, fixed-origin echo of a supported attack | Relocation changes attack geometry | Reduced output, one echo, no echo-of-echo; later experiment |

These are candidate authoring examples, not six new features promised for the first build. Begin with GRAVITON_WAKE only. Add a second effect when it can test a distinct decision.

Existing FORK_ON_KILL and RETURN_VECTOR remain tied to MASS_DRIVER unless a new compatibility implementation explicitly changes that. Existing ARC cards can benefit from clustering without inheriting missile behavior. An upgrade should not quietly change its meaning when the chassis changes.

A beam must not trigger every on-hit effect once per rendered frame. For example, a chain payload could have a per-target interval around 0.35 seconds and a global ceiling around four activations/s. The exact limits belong to the effect definition. Status buildup and damage procs need separate rules; not all effects should share one arbitrary proc model.

Use one root activation ID for a salvo, one for a beam channel, and explicit parent/root IDs for generated effects. Bound both per-event children and concurrent live children. A child can participate in physical interactions without recursively recreating its parent effect.

Powerful builds are desirable. Reject combinations that remove meaningful input, exceed simulation limits, hide threats, or make resources self-refunding forever. Do not flatten every exciting interaction merely because it briefly destroys a wave.

## 8. Red-team findings

| Severity | Attack on the proposal | Observable failure | Required response |
|---|---|---|---|
| Critical | It becomes a manual shooter with automatic decoration | Players ignore process upgrades; active fire determines almost every outcome | Compare with the existing baseline; retain valuable automatic coverage and recovery play |
| Critical | The combo becomes a mandatory rotation | Most engagements start with the same Shift → full M1 sequence regardless of threats | Change enemy spacing and timing; support useful partial attacks and distinct openings |
| Critical | Two-thumb control cannot express the chosen mechanics | Players must stop moving or lift aim to evade reliably | Test slide-to-Shift cancellation and aim assistance before adding kits |
| Critical | Control loops erase enemy behavior | Gravity, stun, cooldown refund, and beam pressure maintain permanent denial | Role resistance, bounded control uptime, refund floors, and explicit proc ancestry |
| High | Charging remains dead behind better particles | The hold provides neither targeting choices nor live battlefield effect | Shorten or remove charge; make the attack channel immediately where appropriate |
| High | A setup is a tax | Unleash feels poor unless paired with the exact gravity patch | Require every base attack to work alone; evaluate the combination separately |
| High | Missiles are spectacular but unreliable | The rack targets enemies killed by automatic fire; shots whiff without feedback | Stable assignment, bounded retarget, visible last-position detonation, useful partial release |
| High | Beam and splash produce proc explosions | Frame rate alters damage; dense clusters multiply chains and FX without limit | Fixed-step damage, per-target intervals, root budgets, area hit caps |
| High | Rewind cancels all risk | Player spends everything, takes damage, then receives the entire state back | Position-only recall; explicit current-world endpoint validation |
| High | Shift is optimal offense and mandatory defense simultaneously | Player feels punished for saving escape because cooldown spam is required for damage | Reduce baseline offensive incentives; make offensive Shift patches compete with alternatives |
| High | Bosses invalidate the control kit | Gravity's main function disappears in the encounter where it matters most | Visible pressure/collapse value against displacement-resistant targets |
| High | Every ship needs bespoke versions of every patch | Compatibility work grows faster than usable content | Two chassis, one form variant each, a small explicit patch matrix |
| Medium | The game cannot explain what caused success | Player sees a glowing pile and assumes a hidden damage bonus | Visible geometry, brief state cues, factual source attribution in the report |
| Medium | Long holds hurt comfort or accessibility | Fatigue or repeated accidental releases | Hold/toggle options, clear cancel semantics, optional auto-release with identical balance rules |
| Medium | Bright terminal effects destroy combat readability | Beam, gravity ring, and missile explosions conceal boss tells | Distinct geometry, restrained fill, readable hostile edges, reduced-effects settings |

### The rotation test is more important than a combo counter

Use encounters where different choices should win: a dispersed ring of weak enemies, a packed chase group, a durable ranged threat, a telegraphed charger crossing from the side, and a boss lane that forces the player to reserve Shift. A setup should be good because the current situation rewards it.

If a single sequence solves all five, increasing cooldowns is unlikely to create interesting variety by itself. Revisit coverage, targeting, spatial commitment, and the enemy openings.

Do not use dynamic boss health to hide an overtuned interaction. Keep comparable encounters fixed while tuning the build.

## 9. Feedback: the ship is part of the attack

The player should identify the held state without reading the top HUD. State changes should be visible at the ship and at the target.

| State | Missile rack | Sustained beam | Gravity clamp |
|---|---|---|---|
| Press | Racks physically open; first cell arms | Rails part; a short ignition bridges them | Intake opens; focal point appears immediately |
| Building / holding | Cells load individually; target allocation updates | Core remains continuous; contact sparks and load sound respond to hits | Ring contracts and actual enemies move; captured mass is readable |
| Ready / committed | Loaded cells hold a clear stable signal | Stable firing state with growing thermal warning | Capped field stops growing; pressure remains visible |
| Payoff | Alternating launches and sequential impacts | Damage exists throughout contact; release is a clear cutoff | Inward collapse followed by a short outward response |
| Recovery | Empty racks close or visibly reload | Rails cool from muzzle toward hull | Field disappears cleanly; intake shuts |
| Cancel | Racks disengage without firing | Beam cuts at once | Field dissipates without a damaging release |

Sound follows those states. Reserve a sustained audio voice for the active weapon so ordinary shot cues do not repeatedly steal its loop. Shape charge pitch by actual charge duration; make contact sound distinguishable from firing into empty space. Use one full-charge cue, not repeated alarms.

Keep the collision core stable when panels extend. Cosmetic recoil must not silently move the player hitbox. Trails stay behind important enemy information. Avoid global hitstop on beam ticks or every missile impact; a constant swarm makes repeated simulation freezes intrusive. Small visual recoil and local enemy hit reactions can convey force without interrupting steering.

Test with shake, bloom, and loud audio removed. The attack still needs a readable state and a convincing result. No gameplay information should depend only on cyan versus magenta.

## 10. Controls, cancellation, and accessibility

| Device | Unleash | Shift | Aim |
|---|---|---|---|
| Mouse / keyboard | M1 press/hold/release | Shift; optionally M2 as a remappable duplicate in the new mode | Mouse direction / clamped field position |
| Controller | Right trigger | Shoulder button reachable while both sticks remain in use | Right stick with target retention or optional assist |
| Touch | Right thumb action pad: hold and drag to aim, release to fire or end channel | Adjacent Shift target plus slide-to-Shift from the active pad | Drag direction; assisted focus distance and explicit target preview |

The touch prototype must handle the hard case: moving with the left thumb while charging or steering with the right, then needing an immediate escape. Sliding the active finger into the Shift region should emit a defensive cancel and Shift, never a release-to-fire event followed by Shift. Do not rely on a third finger.

A separate Shift tap remains available when not holding Unleash. An optional hold/toggle mode can latch a channel or armed state to reduce sustained pressure, with an equally clear cancel. It must not preserve attacks through focus loss or menus.

The first touch interaction may be less precise than mouse input. Give missiles stable locks and gravity a useful default distance. Beam assistance should retain a selected target without instantly sweeping between enemies. Check touch gameplay on a real device before calling the control scheme validated; desktop touch preview is only a construction check.

Input priority is death/pause/focus loss, then defensive cancel, then attack commit. Pause, upgrade selection, end screen, and window focus changes must clear active contacts and require deliberate re-arming. UI clicks cannot fire a charged shot into the resumed game.

## 11. Integration plan for the Godot project

This is an implementation brief, not a request to build a generic ability framework first.

1. **Input intent and action state.** Add device-independent Unleash begin/update/release/cancel and Shift intent. Separate missile arming from beam channel states. Use explicit IDs for each activation. Resolve pause, cancellation, and mixed-device input before adding effects.
2. **Chassis definition.** Keep baseline stats, silhouette parameters, Unleash choice, and Shift choice in a small definition. Preserve the existing weapon controller as the owner of automatic processes.
3. **One missile actor and one salvo controller.** Reuse damage attribution but add target retention, bounded steering, detonation, and direct/splash de-duplication. Do not generate a new complete scene or sound per charge cell.
4. **Common displacement resolver.** Bounds and terrain validation, independent of attack resource state. Keep damage protection explicit. Record uses without treating every Shift as an old VENT event.
5. **One persistent field.** Enemy steering plus an external-force contribution, applied in a defined order. Set a cap and role resistance. Do not piggyback on the current pulse's one-time velocity write.
6. **Beam controller.** Fixed-step contact and damage, swept/continuous visual representation, controlled target list, explicit start/end sound, and a separate proc cadence. Never use a stream of decorative projectiles to fake continuous damage.
7. **Patch compatibility.** Small declared supported matrix, exclusions, replacement UI, and updated card descriptions. Include chassis, new choices, and a version in seeded offer identity. Make no claim of identical combat replays across devices.
8. **Report extension.** Distinguish Unleash direct damage, generated effect damage, automatic-process damage, and Shift damage. Add activations, partial/full releases, canceled charges, charge time, beam contact time, heat spent, and overheat stops. Show positional recall as recall distance rather than ordinary distance traveled.

Useful diagnostic counters include missiles that hit, retarget, or expire; field affected counts; beam contact ratio; Shift uses during a charge; and effect-budget exhaustion. These are local testing tools, not a new telemetry backend.

For combo attribution, keep direct damage assigned exactly once. A field can record “targets grouped, then hit within the field window,” but do not claim causal bonus damage from an invented counterfactual. Display a short combination history only if it helps explain observed actions; do not invent a multiplier or progression gate around it.

The current 180-enemy cap stays. Stress the dangerous configuration: one dense field, a full salvo with area overlap, ARC_FANOUT, forks, returns, the boss, and hostile shots. Track frame-time spikes and active-effect counts on the chosen test device. A low effect count in an empty arena is not evidence of mobile performance.

## 12. Concrete tasks and exit gates

### T0 — Establish a fair comparison

Save a baseline playable mode and define three fixed encounter fixtures: a chase cluster, a dispersed ring with a ranged threat, and a boss lane. Fix their initial conditions independently of combat outcomes. Seed equality alone does not guarantee identical live encounters after different player actions.

Record the control configuration, modifiers, and build version in the test notes. The current user's feedback is a valid problem statement, not a quantified baseline score.

**Exit:** a tester can compare modes without waiting through the whole run, and the fixtures expose grouping, precise targeting, and defensive timing.

### T1 — Make a single unupgraded attack feel alive

Implement Courier's rack sequence, useful tap/partial/full releases, stable target allocation, staggered launch, impact, and clean cancellation. Include sound and ship animation here; they are part of the interaction being tested.

**Exit:** without instruction beyond controls, testers can identify when the weapon is ready, release deliberately, and explain why they fired early at least once. Require a useful baseline effect before adding a synergy patch. If two focused revisions still leave the hold feeling empty, try direct fire or a shorter loading interval before adding content.

### T2 — Build the flagship combination

Add Phase Skip and one selectable GRAVITON_WAKE patch. Demonstrate surge → partial or full salvo → automatic-process continuation. Start with clear loadout selection in the test arena; do not wait for random upgrade luck to expose the mechanic.

**Exit:** grouping visibly changes real splash or chain coverage; players can perform the sequence on keyboard/controller and the touch layout; a different sequence is useful in at least one fixture. No missile receives FORK_ON_KILL merely because it is part of the combination.

### T3 — Test a genuinely different hold

Add Bastion's continuous beam and Breach Step, initially with the same automatic processes to isolate the manual kit. Compare its contact maintenance and escape decision with missile allocation and release. Then test the same gravity patch where compatible.

**Exit:** players describe a different decision while holding the beam, and change positioning between the two kits. Shift always interrupts the channel. Damage and heat are stable at different rendering frame rates. Reject a beam that is merely a stronger, easier missile substitute.

### T4 — Add one form choice and one effect choice

For the surviving kits, offer one delivery replacement and a small effect choice. Retest a build that keeps the existing ARC and driver patches. Keep choice sets curated; defer a full procedural combinatorial pool.

**Exit:** the form changes how players aim, release, or position; the effect creates an understandable interaction; neither is required to repair a bad base attack. Every offered card is legal and accurately describes implemented behavior.

### T5 — Adversarial tests and a five-minute run

Test holding indefinitely, tapping as fast as possible, Shift spam, cancel/repress spam, target death during charge and flight, zero enemies, maximum heat, boss-only encounters, viewport edges, upgrades while held, focus loss, multi-touch cancellation, and simultaneous hit/death events.

Run the existing damage/report regressions plus focused checks for new mechanics: no frame-rate damage drift, no duplicate detonation damage, no recursive proc leak, no resource refund on cancel, no active fire after menu/focus transitions, and exact source totals. Add recall history/reset tests only when recall is actually built.

**Exit:** no stuck input or illegal escape endpoints; no self-sustaining cooldown loop; understandable late-run visuals; consistent attribution; useful automatic weapons; and voluntary replay to try a different combination. Replaying the identical seed is not a requirement.

### T6 — Decide whether to expand

Only then consider the full gravity chassis, position recall, additional forms, or chassis-specific starter processes. A fourth chassis is not the remedy for a first chassis that still feels bad.

No calendar estimate is attached until the first attack and input contract have been measured. Price, launch plans, a content roadmap, full replay determinism, adaptive compilation, and meta progression do not resolve this experiment and are outside it.

## 13. Playtest questions and decisions

Start with a small formative group, for example five players across relevant input modes, and alternate which prototype they try first. That sample can reveal repeated failures; it cannot prove population-wide preference. Ask questions after an uncoached attempt rather than explaining the intended combo beforehand.

- What was happening while you held the button?
- What made you release or stop firing?
- What did Shift change besides your position?
- Did you ever abandon an attack to survive? Did the input do what you expected?
- Which two effects worked together, and why?
- When was your usual combination the wrong choice?
- What would you change in the next build?

Use ratings as supporting evidence, with separate scores for charge responsiveness, payoff, control, and readability. Track median hold length, incomplete charges, repeated identical openings, active versus automatic damage, and damage taken around activations. A high damage share is not itself a failure; it becomes concerning when process choices stop changing play.

Provisional decision rules: if most players cannot identify readiness or predict release behavior, revise the interaction before tuning damage. If most cannot explain one physical combination after trying the loadouts, simplify its feedback or rules. If everyone repeats one sequence across all fixtures, change the decisions rather than adding more upgrades. A single reliable stuck-input or resource-duplication exploit blocks expansion regardless of preference scores.

The first deliverable worth playing is one ship whose rack visibly loads, whose missiles actually arrive with force, whose gravity-modified Shift creates an exploitable cluster, and whose existing processes respond to that new geometry. That is enough to test the emergent loop the user is describing.
