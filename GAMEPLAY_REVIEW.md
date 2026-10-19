# Gameplay continuity review — 2026-10-02

This review covers the runnable prototype and the new combat/UI pass. Engagement is a hypothesis until people play it. Passing a smoke test proves execution, not fun. ROADMAP.md supersedes the original production timeline in GAME_PLAN.md.

## Intended loop

Choose a starter ship -> move to shape enemy clusters -> automatic DRIVER clears lines and automatic ARC punishes nearby groups -> charge precision for a chosen high-value target -> guard a dangerous crossing or boost into open space -> collect XP -> choose a modification -> recognize its effect on the ship schematic -> survive the boss.

Movement and build choices remain the foundation. The three manual actions should create decisions without demanding constant button maintenance. Automatic weapons remain active during guard and charge.

## Feature review

| Feature | Current contract | Gameplay judgment / next check |
| --- | --- | --- |
| Starter choice | Courier balanced; Bastion slower and armored with heavy shots; Redline fragile, fast, rapid primary and frequent boost; Conductor stronger/faster ARC and better cooling | Distinct numerical starting profiles, not yet four unique weapon kits. Compare survival, source damage, and perceived playstyle before adding more. |
| Movement / aim | Keyboard or stick moves. Mouse biases automatic DRIVER targets and aims precision. ARC selects proximity targets independently | This resolves the second weapon's role. DRIVER's aim cone can still make shots wait when nothing is in front; show that distinction more explicitly next pass. |
| Automatic DRIVER | Baseline 24 damage, 0.72s cadence, one additional penetration, 1.05s lifetime; heat and overclock change cadence | Keep existing pace. Dense-line targeting currently scans many enemy pairs and needs profiling before increasing swarm size. |
| Precision | Hold M1 for up to 0.9s; release for 1.2–4x primary damage and 2–6 additional penetrations; costs 8–20 heat | An additive target-selection tool. No recursive forks or return effects from precision. Charge must reward deliberate aim, not become compulsory sustained DPS. Guard cancels it; opening Escape clears it. |
| Automatic ARC | At most once per base 1.18s, starts within 260 units, base three contacts, 140-unit jumps with 10% damage falloff per jump | Close-range area pressure distinguishes it from DRIVER. Range changes require balancing against ranged enemies and boss orbit distance. |
| Guard | Hold M2/Space. 80% mitigation, 55% movement speed, drains 38 guard/s plus 1.5 guard per prevented damage. Regenerates 24/s; broken guard must reach 30 before reuse | Finite duration prevents permanent defense. Omnidirectional protection is provisional; directional guard is a later experiment, not an assumed improvement. Existing post-hit grace may still make guard too strong. |
| Vent + boost | Shift dumps heat, emits the existing radial pulse, gives brief immunity and 0.55s directional thrust. Defaults to movement direction, then aim | Added movement payoff makes vent useful at low heat. Offensive power still scales with dumped heat. Shared cooldown gives a choice between cooling, escape, and high-heat damage. |
| Shield / hull | Shield absorbs first, restores after a delay; hull does not passively regenerate | Separate hit feedback now distinguishes shield and hull. A combined integrity bar alone is insufficient; split bars are a near-term follow-up. |
| XP / upgrades | Pickups attract near the ship; first two offers teach behavioral upgrades; later cards depend on seed, level, and current ranks | Good early demonstration, but forced first offers bias build diversity. Compare against fully seeded offers after comprehension improves. |
| Enemy roles | BIT pursues, VECTOR winds up then charges, SENTRY maintains range then fires | Short local dashed intent lines replace the 520-unit screen-crossing telegraphs. They show direction, not full travel length. Charge endpoints / corridor width remain a playtest check. |
| Wave pressure | Time increases batch size, health, speed and spawn frequency, up to 180 normals | Simultaneously raising too many variables risks an opaque difficulty wall. Measure density and damage at 60/120/180/240 seconds; vary one tuning axis at a time. |
| Boss | At 300s, clears hostile projectiles, keeps survivors, reduces subsequent spawn rate; fixed health, three projectile patterns / health phases | Pattern tells are currently too similar. Give each pattern its own shape and transition grace before adding protocols or bosses. Remaining swarm may undermine the opening read. |
| Seed | Upgrade offers, spawn type/placement sequence, decoration are seeded | Same seed is a shared content setup, not a combat replay guarantee. Player actions change deaths, XP timing, ranks, and therefore later offers. State that plainly. |
| DPS | Actual applied damage from every source, clamped to remaining health; trailing five seconds of simulation time, startup window shorter than five seconds | Includes ARC, vent, forks and returns. Excludes overkill and blocked damage. Source totals in Escape explain build contribution. DPS is diagnostic, not the objective. |
| Damage numbers | Per-hit world labels colored by weapon, bounded to 40 concurrent labels | Reduces clutter but can suppress hits during peak density. Aggregating by target/source would communicate bursts better than more labels. |
| Hit UX | Hull/shield text, floating loss, short screen tint, existing ring/shake | Clearer impact. Tint and shake need user intensity controls; no rapid flashing should be added. Directional hit markers are still useful. |
| Ship diagram | Simplified ship, gun and ARC modules, precision charge ring, fork children; installed ranks and some physical modification marks | Pulses show actual weapon/fork events. Explains DRIVER kill -> child shots at 45% damage -> no grandchildren. Still needs tooltips and a compact mobile mode. |
| Escape | Scrollable current resources, effective cooldowns, movement, cadence/throttle, source damage, controls, every installed upgrade/rank/description; fixed action buttons | Inspection is separated from transient combat feedback. Resize and lowest-height phone layouts need another device pass. |
| Restart / end | End summary with wrapped build; restart returns to starter choice; pause restores simulation state | Restart discards run progress as expected. Suspend/resume persistence remains unimplemented. |

## Every upgrade: rule and consistency audit

| Upgrade | Live effect and continuity finding |
| --- | --- |
| FORK_ON_KILL | A lethal original DRIVER hit creates up to one nearest-target child per rank at 45% parent damage. Children cannot fork or return. No children appear if no legal nearby targets exist. The schematic and combat log now explain this. |
| RETURN_VECTOR | Original DRIVER rounds surviving until lifetime expiry emit a new return projectile aimed at the ship's position at that instant. Collision-expired rounds do not return. Return projectiles can hit earlier victims again; they cannot recurse. Needs an explicit returning-arrow tutorial. |
| DRIVER_RAIL | Adds penetration and now actually narrows the automatic aim cone as advertised. This changes target eligibility, not physical projectile radius. |
| CONDUCTIVE_MARK | Extra ARC contacts and prioritization of last surviving contact inside the start radius. The unimplemented timed-mark claim was removed. Mark priority is now gated by owning the upgrade. |
| ARC_FANOUT | Additional branches from first contact; excluded targets stop duplicate hits across branches. Extra heat. Branches no longer draw independent long connections from the ship. |
| GROUND_LOOP | Full chains reduce vent cooldown by 0.18s per rank per completed branch. No refund if the branch runs out of eligible enemies. Ties ARC clustering to mobility recovery. |
| HULL_PLATING | Adds and fills 18 hull per purchased rank. Immediate recovery makes it a strong low-health choice. |
| KINETIC_DAMPERS | Extends hit grace by 0.12s per rank and adds brief escape thrust after any hit. Description now matches shield as well as hull triggers. |
| SHIELD_CAPACITOR | Adds and fills 12 shield per purchased rank. Distinguish it from hull by recovery potential, not only hit point totals. |
| SHIELD_REBOOT | Reduces regeneration delay by 0.35s per rank and restores 3 shield per current rank on purchase. Removed misleading automatic recovery-burst wording. |
| VENT_AMPLIFIER | Adds pulse radius and force, does not independently increase damage. Useful for spatial control and now boost setup. |
| VENT_COOLANT | Reduces shared vent/boost cooldown by 0.45s per rank. Removed a nonexistent retained-heat tradeoff. |
| OVERCLOCK_KERNEL | Speeds automatic processes, increases heat, adds high-heat vent damage. Precision damage/cadence is deliberately separate; verify that choice in play. |

## Fixed in this pass

Damage accounting now uses actual health loss for all sources, rather than only projectile nominal damage. Guard cannot instantly flutter back on at zero resource. Modals clear touch guard. Pause clears precision charge so resuming cannot accidentally release a stored shot. ARC does not revisit already hit targets across branches. Persistent visual effects finish fading during modal pauses. Upgrade explanations match live behavior more closely.

## Remaining highest-priority risks

1. Precision plus the base auto loop may erase specialists too quickly. Tune heat and charge time using actual target kills, not theoretical DPS alone.
2. Guard + existing collision grace + shield regeneration may trivialize sustained pressure. Test cornered and projectile-heavy situations, not only free movement.
3. Boost can become mandatory cooldown spam rather than a tactical action. Watch whether players save it for a gap or press it every time the button lights up.
4. The ship diagram occupies combat space. Keep its interpretation value, but provide compact/toggle modes and move detailed modifiers to Escape.
5. Behavior patches still depend on target availability. A player selecting FORK without enough killable targets may think it is broken. Add a short upgrade preview and trigger-condition tooltip.
6. Boss pattern identity and the mid-run specialist introduction are weaker than the weapon systems. Solve those before content breadth.
7. Damage calculations and thresholds are dispersed across scripts; upgrade effect dictionaries are descriptive, not authoritative executable rules. Consolidate effective stats once the current tuning is stable.

## Playtest gates

Within the first minute, a player should identify which shot is automatic DRIVER, which effect is ARC, and when precision fires. After a fork upgrade, they should explain the kill trigger and lack of recursive children without reading source code. During a hit they should know whether shield or hull was lost. Escape should answer why a build deals its damage. At least one restart should be motivated by a different ship/build experiment. None of these gates requires replaying the same seed.

Record confusion points, chosen upgrades, death causes, guard/boost usage, precision hit rate, per-source damage and voluntary restarts. Do not interpret a clean automated test as evidence that these gates passed.
