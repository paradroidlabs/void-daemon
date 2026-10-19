# Experience checkpoint — four ships, one control language

Build `desktop-2026.10.19.3`, October 19, 2026. Prove the experience by playing; these are first playable tuning values, not a declaration that four ships are balanced. The .2 executable was the hands-on packaging candidate; .3 preserves it in place for the user and adds persistent title/build identification.

## Start

Open `VOID-DAEMON.exe` → choose a chassis → Deploy or Combat Lab. Pause → Hangar to change ships or sound/effects settings. Death/victory also offers Hangar. Direct `Play Combat Lab.cmd` opens Graviton; source `--chassis=bastion|scrapper|redline --combo-lab` selects another directly. `--direct-flight` preserves the old direct handling for comparison; `--classic` preserves the previous automatic/VENT rules.

## Controls and flight instruments

WASD/arrows and left stick are **directional thrust**, not forward-only tank controls. Mouse/right stick aim independently. Release thrust and drift; aim elsewhere and momentum remains. Counter-thrust brakes; sideways thrust bends the vector. Exponential drag gradually dissipates speed. Navigation wells apply softened, bounded forces; they cannot create singularities or unavoidable infinite acceleration. This is readable game physics, not an orbital simulator.

Hold M1 / RT / right touch pad to operate the chassis attack. Release launches Graviton's missiles, collapses Scrapper's field, or stops Bastion/Redline. Shift, Space, RB and A alias the **same maneuver and cooldown**, not shield or a second ability. Shield regenerates passively. Touch: left stick thrust, right hold/drag aim, release attack; tap the labeled maneuver or slide into it to cancel the attack before escaping. Pause or loss of focus cancels uncommitted attacks.

Flight recorder: arena-relative speed, cyan nose heading, amber travel bearing, heading/track slip, thrust percentage, drag and gravity acceleration. The amber prograde marker and dotted no-thrust trajectory remain independent of the ship's nose. A purple arrow shows gravity. Compact gameplay retains numeric speed/slip/gravity rather than covering the playfield with the full instrument panel. The hangar/settings use touch-sized controls and compact scrolling; the desktop scorecard remains one non-scrolling sheet.

Combat renders in a separate clipped viewport between the 82px status rail (plus a 50px lab toolbar in the lab) and the 120px instrument dock. Telemetry, hive PiP, captions and zoom controls occupy those reserved bands, not combat pixels. Mouse wheel or `+`/`−` adjusts zoom; dock buttons provide the same action without requiring a pinch during two-thumb play. Default 82%, bounded 65–125%. Aiming uses the actual offset/zoom transform. Spawns account for the visible world rectangle, including zoom; at world bounds the system chooses a farther valid direction, and never invents an offscreen location if a very large window sees the whole arena.

## Initial chassis tuning

| Chassis | Hull + shield | Cruise / thrust / drag | Manual attack | Maneuver |
|---|---|---|---|---|
| Graviton | 100 + 30 | 285 / 560 / .25 | Hold gathers max 12 contacts; .8s loads six missiles. Startup 8 heat, 4 per committed missile. | Phase Skip: 210u / 4.2s |
| Bastion | 145 + 45 | 230 / 380 / .20 | .18s ignition; 610u continuous beam. 16 damage per .1s to max three line contacts. 4 startup + 2 heat/tick. | Breach Step: 140u / 5s, pushes nearby normals |
| Scrapper | 115 + 35 | 260 / 470 / .32 | External clamp, max 12 contacts, 2.8s control window. Release 55–120 collapse damage/contact. 8 startup + 13 heat/s + 12 collapse. | Tow Step: 165u / 5s, 1.4s decoy, max 12 normals |
| Redline | 85 + 20 | 325 / 760 / .28 | .18s ignition; 220u forward plasma cone, max six contacts. 19 damage × (1 + .65 heat ratio) per .16s. 4 startup + 5.5 heat/tick. | Backtrace: recent ~1.2s position, max 350u / 6.5s |

Cruise and thrust are units/s and units/s²; drag is /s. Cooling: 22 / 22 / 24 / 28 heat/s respectively. Shared automatic weapons add heat too. A full reactor stops an unaffordable channel; no resource is refunded by canceling. Backtrace preserves current momentum, hull, heat, XP, cooldowns and world state; no history gives a short 130u escape. All maneuvers respect arena bounds and current blocking geometry.

Shared automatic DRIVER/ARC and their upgrades remain. Manual attacks do not inherit hidden fork/chain multipliers. Grouping changes geometry, making actual automatic chains/returns more useful. Obsolete VENT-only patches are excluded from these kits. Overclock affects automatic cadence and shared reactor pressure, not manual tick frequency.

## Hive and sound pass

The hive notices actual cross-drift, coasting under gravity, reactor heat, shield depletion, repeated attacks, repeated maneuvers and boss phases. It gets no personal files, microphone, online model or outside-game knowledge. A live tactical PiP uses nearby enemy positions and your actual travel vector. Terminal transmissions have subtitles, a seven-and-a-half-second display window, a 22-second observation cooldown and bounded history; no dialogue modal stops combat. Disabling PiP leaves the smaller subtitle band. Pause/end/menu silence speech and hide the feed.

Speech uses Godot's [system TTS interface](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-tts-speak), with an installed English voice and subtitle fallback. Three English voices were available in the rendered desktop fixture; this is not bespoke acted audio. Procedural sound now separates continuous kit identity, actual thrust/coast, a quiet void bed, transient attack/impact cues and reserved critical voices. Hive feeds duck effects. Master/effects/voice volume, speech, PiP and reduced-effects settings are available in the hangar and persist locally. Master zero mutes both game audio and speech. Reduced effects disables camera shake and reduces typing/weapon animation; it is not a photosensitivity certification.

## Playtest sequence

1. Fly the Orbit Field [F8] without firing: accelerate, release, rotate, counter-thrust, enter/leave the gravity field. Can you predict where you will go? Does the telemetry explain it without becoming homework?
2. Compare each ship in Cluster, Dispersed and Boss. Does M1 make you commit differently? Does the maneuver solve a different problem? Are hull/heat/handling tradeoffs noticeable?
3. F4 isolates the manual attack on the new ships, F5 restores base autos, F6 adds the patched chain. Original Graviton F4 retains baseline autos for its existing salvo-vs-gravity comparison. The room waits for the first hold; R resets; F7 reports actual results.
4. Try attacking while drifting, cancel into a maneuver, pause while holding, change focus, restart and return to hangar. Look for stuck sound, unintended release damage, stale targets or old Backtrace history.
5. Play survival normally. Are hive comments earned and sparse enough? Are sound roles useful without becoming fatiguing? Compare full/reduced effects and speech muted. Inspect per-source damage, kit, heat and flight statistics on the final card.

## Evidence and open gates

Automated checks cover independent heading/travel, coast/counter-thrust, bounded gravity and speed, 30/60/120Hz channel damage cadence, heat stops, target caps, cancellation, decoy cleanup, position-only Backtrace, reset, legal upgrades, exact damage/overkill and final boss-hit scorecard capture. Menu selection launches the actual selected kit, and returning from pause unwinds pause state. Audio checks cover generated waveform headroom, cue coverage, bounded voices, loop cancellation, ducking and mute. These do not prove a pleasing mix.

Rendered fixtures on this AMD Radeon desktop cover the actual hangar, beam, hive feed, flight panel, scorecard, settings and compact hangar/settings. The inherited 180-enemy-plus-boss stress fixture is a bounded correctness/performance probe, not certification of stable 60 FPS. Headless audio teardown can report engine playback references at process exit; rendered fixture teardown has not reproduced that warning. Keep this distinction visible.

Human gates remain: full survival without debug assistance on each chassis, whether the combos are fun, relative power and maneuver safety, actual listening/voice preference, physical controller, real phone/touch, and device frame pacing. Report build + chassis + fixture/loadout or seed + input + the specific thing that felt wrong. Do not turn a passing scripted fixture into a claim that those gates passed.

## Build identity

The `4ade` worktree contains a distinct Courier/Guard/Boost experiment with a full four-tab pause dashboard. A running process was verified to use that worktree when the user reported the obstructing module panel. It is not the Graviton checkpoint. Its panel fix, isolated combat view and zoom are preserved on `codex/courier-ui-checkpoint`; its controls remain M1 precision, M2/Space guard and Shift boost. Do not silently substitute either control contract for the other. The packaged four-chassis build identifies itself as `desktop-2026.10.19.3` in the hangar footer/title.
